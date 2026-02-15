#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use tauri::{AppHandle, GlobalShortcutManager, State};

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct PermissionStatus {
  global_shortcut_ready: bool,
  clipboard_ready: bool,
  note: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct SetupPayload {
  provider: String,
  api_key: String,
  action_name: String,
  prompt: String,
  setup_completed_at: String,
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

  PermissionStatus {
    global_shortcut_ready,
    clipboard_ready: true,
    note:
      "Global shortcut probe executed. Clipboard APIs are available in the desktop runtime."
        .to_string(),
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

  shortcut_manager
    .register(&normalized, || {})
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

#[tauri::command]
fn load_setup(handle: AppHandle) -> Result<Option<SetupPayload>, String> {
  let path = setup_file_path(&handle)?;
  read_json::<SetupPayload>(&path)
}

#[tauri::command]
fn save_setup(handle: AppHandle, setup: SetupPayload) -> Result<(), String> {
  let path = setup_file_path(&handle)?;
  write_json(&path, &setup)
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
  tauri::Builder::default()
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
      load_setup,
      save_setup,
      load_execution_logs,
      append_execution_log
    ])
    .run(tauri::generate_context!())
    .expect("error while running shortcutai windows app");
}
