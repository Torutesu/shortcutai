#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use arboard::Clipboard;
use enigo::{Enigo, Key, KeyboardControllable};
use keyring::Entry;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use std::thread;
use std::time::Duration;
use tauri::{
  AppHandle, CustomMenuItem, GlobalShortcutManager, Manager, State, SystemTray, SystemTrayEvent,
  SystemTrayMenu, SystemTrayMenuItem,
};

#[derive(Debug, Serialize, Clone)]
#[serde(rename_all = "camelCase")]
struct PermissionStatus {
  global_shortcut_ready: bool,
  clipboard_ready: bool,
  note: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct Action {
  id: String,
  name: String,
  prompt: String,
  created_at: String,
  last_used_at: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct SetupPayload {
  provider: String,
  api_key: String,
  actions: Vec<Action>,
  default_action_id: Option<String>,
  setup_completed_at: String,
}

/// Internal structure for storing setup without API key in JSON.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct SetupFile {
  provider: String,
  actions: Vec<Action>,
  default_action_id: Option<String>,
  setup_completed_at: String,
  /// Legacy field for backward compatibility migration.
  #[serde(skip_serializing_if = "Option::is_none")]
  api_key: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct ExecutionLogEntry {
  id: String,
  timestamp: String,
  action_id: String,
  action_name: String,
  prompt: String,
  provider: Option<String>,
  model_id: Option<String>,
  duration_ms: f64,
  input_length: u32,
  output_length: u32,
  success: bool,
  error_message: Option<String>,
}

#[derive(Default)]
struct AppState {
  logs: Mutex<Vec<ExecutionLogEntry>>,
  active_shortcut: Mutex<Option<String>>,
}

fn app_data_dir(handle: &AppHandle) -> Result<PathBuf, String> {
  let dir = tauri::api::path::app_data_dir(&handle.config())
    .ok_or_else(|| "Unable to resolve app data directory".to_string())?;

  fs::create_dir_all(&dir)
    .map_err(|error| format!("Failed to create app data directory: {error}"))?;

  Ok(dir)
}

fn setup_file_path(handle: &AppHandle) -> Result<PathBuf, String> {
  Ok(app_data_dir(handle)?.join("setup.json"))
}

fn logs_file_path(handle: &AppHandle) -> Result<PathBuf, String> {
  Ok(app_data_dir(handle)?.join("execution-logs.json"))
}

fn read_json<T: for<'de> Deserialize<'de>>(path: &Path) -> Result<Option<T>, String> {
  if !path.exists() {
    return Ok(None);
  }

  let raw = fs::read_to_string(path)
    .map_err(|error| format!("Failed to read JSON file {}: {error}", path.display()))?;

  let parsed = serde_json::from_str::<T>(&raw)
    .map_err(|error| format!("Failed to parse JSON file {}: {error}", path.display()))?;

  Ok(Some(parsed))
}

fn write_json<T: Serialize>(path: &Path, value: &T) -> Result<(), String> {
  let raw = serde_json::to_string_pretty(value)
    .map_err(|error| format!("Failed to serialize JSON for {}: {error}", path.display()))?;

  fs::write(path, raw)
    .map_err(|error| format!("Failed to write JSON file {}: {error}", path.display()))?;

  Ok(())
}

fn load_logs_from_disk(handle: &AppHandle) -> Vec<ExecutionLogEntry> {
  match logs_file_path(handle).and_then(|path| read_json::<Vec<ExecutionLogEntry>>(&path)) {
    Ok(Some(logs)) => logs,
    _ => Vec::new(),
  }
}

/// Get keyring entry for secure API key storage.
fn get_keyring_entry() -> Result<Entry, String> {
  Entry::new("ShortcutAI", "api_key")
    .map_err(|error| format!("Failed to access keyring: {error}"))
}

/// Save API key securely to Windows Credential Manager.
fn save_api_key_secure(api_key: &str) -> Result<(), String> {
  let entry = get_keyring_entry()?;
  entry
    .set_password(api_key)
    .map_err(|error| format!("Failed to save API key to keyring: {error}"))
}

/// Load API key securely from Windows Credential Manager.
fn load_api_key_secure() -> Result<Option<String>, String> {
  let entry = get_keyring_entry()?;
  match entry.get_password() {
    Ok(password) => Ok(Some(password)),
    Err(keyring::Error::NoEntry) => Ok(None),
    Err(error) => Err(format!("Failed to load API key from keyring: {error}")),
  }
}

/// Delete API key from Windows Credential Manager.
#[allow(dead_code)]
fn delete_api_key_secure() -> Result<(), String> {
  let entry = get_keyring_entry()?;
  match entry.delete_password() {
    Ok(()) => Ok(()),
    Err(keyring::Error::NoEntry) => Ok(()), // Already deleted
    Err(error) => Err(format!("Failed to delete API key from keyring: {error}")),
  }
}

/// Capture selected text from the foreground application via Ctrl+C simulation.
/// Returns the captured text, or an empty string if nothing was selected.
fn capture_selected_text() -> String {
  // Save current clipboard contents so we can restore after capture.
  let mut board = match Clipboard::new() {
    Ok(b) => b,
    Err(_) => return String::new(),
  };
  let previous = board.get_text().unwrap_or_default();

  // Clear clipboard so we can detect whether Ctrl+C produced a new value.
  let _ = board.set_text("");

  // Simulate Ctrl+C to copy the selected text.
  let mut enigo = Enigo::new();
  enigo.key_down(Key::Control);
  enigo.key_click(Key::Layout('c'));
  enigo.key_up(Key::Control);

  // Wait for the target application to write to the clipboard.
  thread::sleep(Duration::from_millis(150));

  // Read the (possibly new) clipboard value.
  let captured = board.get_text().unwrap_or_default();

  // Restore the previous clipboard content.
  let _ = board.set_text(&previous);

  captured
}

#[tauri::command]
fn check_windows_permissions(handle: AppHandle) -> PermissionStatus {
  let probe_shortcut = "Ctrl+Shift+Alt+9";
  let mut shortcut_manager = handle.global_shortcut_manager();

  let global_shortcut_ready = match shortcut_manager.register(probe_shortcut, || {}) {
    Ok(()) => {
      let _ = shortcut_manager.unregister(probe_shortcut);
      true
    }
    Err(_) => false,
  };

  let clipboard_ready = Clipboard::new().is_ok();

  PermissionStatus {
    global_shortcut_ready,
    clipboard_ready,
    note: "Permission probe complete.".to_string(),
  }
}

#[tauri::command]
fn register_global_shortcut(
  handle: AppHandle,
  state: State<'_, AppState>,
  shortcut: String,
) -> Result<(), String> {
  let normalized = shortcut.trim().to_string();
  if normalized.is_empty() {
    return Err("Shortcut cannot be empty".to_string());
  }

  let mut registered = state
    .active_shortcut
    .lock()
    .map_err(|_| "Failed to lock shortcut state".to_string())?;

  let mut shortcut_manager = handle.global_shortcut_manager();

  if let Some(previous) = registered.as_ref() {
    if previous == &normalized {
      return Ok(());
    }
    let _ = shortcut_manager.unregister(previous);
  }

  let app_handle = handle.clone();
  shortcut_manager
    .register(&normalized, move || {
      let h = app_handle.clone();
      thread::spawn(move || {
        // Capture selected text while the original app still has focus.
        let text = capture_selected_text();

        // Emit the captured text to the frontend.
        let _ = h.emit_all("text-captured", &text);

        // Bring the ShortcutAI window into view.
        if let Some(window) = h.get_window("main") {
          let _ = window.show();
          let _ = window.unminimize();
          let _ = window.set_focus();
        }
      });
    })
    .map_err(|error| format!("Failed to register shortcut: {error}"))?;

  *registered = Some(normalized);
  Ok(())
}

#[tauri::command]
fn unregister_global_shortcut(
  handle: AppHandle,
  state: State<'_, AppState>,
) -> Result<(), String> {
  let mut registered = state
    .active_shortcut
    .lock()
    .map_err(|_| "Failed to lock shortcut state".to_string())?;

  let Some(existing) = registered.clone() else {
    return Ok(());
  };

  let mut shortcut_manager = handle.global_shortcut_manager();
  shortcut_manager
    .unregister(&existing)
    .map_err(|error| format!("Failed to unregister shortcut: {error}"))?;

  *registered = None;
  Ok(())
}

/// Write `text` to the clipboard, then simulate Ctrl+V to paste it into the
/// foreground application.  The window must have been hidden or blurred first
/// so that the original application receives the paste event.
#[tauri::command]
fn paste_text(text: String) -> Result<(), String> {
  let mut board =
    Clipboard::new().map_err(|error| format!("Clipboard init failed: {error}"))?;

  board
    .set_text(&text)
    .map_err(|error| format!("Clipboard write failed: {error}"))?;

  // Small delay to let the clipboard settle before simulating the paste.
  thread::sleep(Duration::from_millis(80));

  let mut enigo = Enigo::new();
  enigo.key_down(Key::Control);
  enigo.key_click(Key::Layout('v'));
  enigo.key_up(Key::Control);

  Ok(())
}

#[tauri::command]
fn hide_window(handle: AppHandle) -> Result<(), String> {
  if let Some(window) = handle.get_window("main") {
    window
      .hide()
      .map_err(|error| format!("Failed to hide window: {error}"))?;
  }
  Ok(())
}

#[tauri::command]
fn load_setup(handle: AppHandle) -> Result<Option<SetupPayload>, String> {
  let path = setup_file_path(&handle)?;
  let setup_file = match read_json::<SetupFile>(&path)? {
    Some(s) => s,
    None => return Ok(None),
  };

  // Migration: If api_key exists in JSON (legacy), move it to keyring.
  if let Some(legacy_api_key) = &setup_file.api_key {
    if !legacy_api_key.is_empty() {
      save_api_key_secure(legacy_api_key)?;

      // Remove api_key from JSON file after migration.
      let migrated = SetupFile {
        provider: setup_file.provider.clone(),
        actions: setup_file.actions.clone(),
        default_action_id: setup_file.default_action_id.clone(),
        setup_completed_at: setup_file.setup_completed_at.clone(),
        api_key: None,
      };
      write_json(&path, &migrated)?;
    }
  }

  // Load API key from keyring.
  let api_key = load_api_key_secure()?.unwrap_or_default();

  Ok(Some(SetupPayload {
    provider: setup_file.provider,
    api_key,
    actions: setup_file.actions,
    default_action_id: setup_file.default_action_id,
    setup_completed_at: setup_file.setup_completed_at,
  }))
}

#[tauri::command]
fn save_setup(handle: AppHandle, setup: SetupPayload) -> Result<(), String> {
  // Save API key to Windows Credential Manager.
  save_api_key_secure(&setup.api_key)?;

  // Save everything else to JSON file (without API key).
  let setup_file = SetupFile {
    provider: setup.provider,
    actions: setup.actions,
    default_action_id: setup.default_action_id,
    setup_completed_at: setup.setup_completed_at,
    api_key: None, // Never store API key in JSON
  };

  let path = setup_file_path(&handle)?;
  write_json(&path, &setup_file)
}

#[tauri::command]
fn load_execution_logs(state: State<'_, AppState>) -> Result<Vec<ExecutionLogEntry>, String> {
  let logs = state
    .logs
    .lock()
    .map_err(|_| "Failed to lock log state".to_string())?
    .clone();

  Ok(logs)
}

#[tauri::command]
fn append_execution_log(
  handle: AppHandle,
  state: State<'_, AppState>,
  entry: ExecutionLogEntry,
) -> Result<Vec<ExecutionLogEntry>, String> {
  let mut logs = state
    .logs
    .lock()
    .map_err(|_| "Failed to lock log state".to_string())?;

  logs.push(entry);
  if logs.len() > 500 {
    let trim_count = logs.len() - 500;
    logs.drain(0..trim_count);
  }

  let updated = logs.clone();
  let path = logs_file_path(&handle)?;
  write_json(&path, &updated)?;

  Ok(updated)
}

fn main() {
  let show_item = CustomMenuItem::new("show", "Show ShortcutAI");
  let quit_item = CustomMenuItem::new("quit", "Quit");

  let tray_menu = SystemTrayMenu::new()
    .add_item(show_item)
    .add_native_item(SystemTrayMenuItem::Separator)
    .add_item(quit_item);

  let system_tray = SystemTray::new().with_menu(tray_menu);

  tauri::Builder::default()
    .system_tray(system_tray)
    .on_system_tray_event(|app, event| match event {
      SystemTrayEvent::LeftClick { .. } => {
        if let Some(window) = app.get_window("main") {
          let _ = window.show();
          let _ = window.unminimize();
          let _ = window.set_focus();
        }
      }
      SystemTrayEvent::MenuItemClick { id, .. } => match id.as_str() {
        "show" => {
          if let Some(window) = app.get_window("main") {
            let _ = window.show();
            let _ = window.unminimize();
            let _ = window.set_focus();
          }
        }
        "quit" => {
          std::process::exit(0);
        }
        _ => {}
      },
      _ => {}
    })
    .setup(|app| {
      let app_handle = app.handle();
      let logs = load_logs_from_disk(&app_handle);
      app.manage(AppState {
        logs: Mutex::new(logs),
        active_shortcut: Mutex::new(None),
      });
      Ok(())
    })
    .invoke_handler(tauri::generate_handler![
      check_windows_permissions,
      register_global_shortcut,
      unregister_global_shortcut,
      paste_text,
      hide_window,
      load_setup,
      save_setup,
      load_execution_logs,
      append_execution_log
    ])
    .run(tauri::generate_context!())
    .expect("error while running shortcutai windows app");
}
