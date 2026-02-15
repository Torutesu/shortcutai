import { invoke } from "@tauri-apps/api/tauri";
import { readText as tauriReadClipboardText, writeText as tauriWriteClipboardText } from "@tauri-apps/api/clipboard";
import type { ExecutionLogEntry } from "../../../shared/core/src";

export interface SetupPayload {
  provider: string;
  apiKey: string;
  actionName: string;
  prompt: string;
  setupCompletedAt: string;
}

export interface PermissionStatus {
  globalShortcutReady: boolean;
  clipboardReady: boolean;
  note?: string;
}

const SETUP_KEY = "shortcutai_windows_setup";
const LOGS_KEY = "shortcutai_windows_execution_logs";

function isTauriRuntime(): boolean {
  return typeof window !== "undefined" && "__TAURI_IPC__" in window;
}

function parseJson<T>(raw: string | null): T | null {
  if (!raw) return null;
  try {
    return JSON.parse(raw) as T;
  } catch {
    return null;
  }
}

export async function checkPermissions(): Promise<PermissionStatus> {
  if (isTauriRuntime()) {
    try {
      return await invoke<PermissionStatus>("check_windows_permissions");
    } catch {
      return {
        globalShortcutReady: false,
        clipboardReady: false,
        note: "Tauri permission check failed.",
      };
    }
  }

  return {
    globalShortcutReady: false,
    clipboardReady: true,
    note: "Browser preview mode. Native permission checks are disabled.",
  };
}

export async function loadSetup(): Promise<SetupPayload | null> {
  if (isTauriRuntime()) {
    try {
      return await invoke<SetupPayload | null>("load_setup");
    } catch {
      return null;
    }
  }

  return parseJson<SetupPayload>(localStorage.getItem(SETUP_KEY));
}

export async function saveSetup(setup: SetupPayload): Promise<void> {
  if (isTauriRuntime()) {
    try {
      await invoke("save_setup", { setup });
      return;
    } catch {
      // Fallback to browser storage.
    }
  }

  localStorage.setItem(SETUP_KEY, JSON.stringify(setup));
}

export async function loadExecutionLogs(): Promise<ExecutionLogEntry[]> {
  if (isTauriRuntime()) {
    try {
      return await invoke<ExecutionLogEntry[]>("load_execution_logs");
    } catch {
      return [];
    }
  }

  return parseJson<ExecutionLogEntry[]>(localStorage.getItem(LOGS_KEY)) ?? [];
}

export async function appendExecutionLog(
  entry: ExecutionLogEntry,
): Promise<ExecutionLogEntry[]> {
  if (isTauriRuntime()) {
    try {
      return await invoke<ExecutionLogEntry[]>("append_execution_log", { entry });
    } catch {
      // Fallback to browser storage.
    }
  }

  const logs = [...(await loadExecutionLogs()), entry].slice(-500);
  localStorage.setItem(LOGS_KEY, JSON.stringify(logs));
  return logs;
}

export async function registerGlobalShortcut(shortcut: string): Promise<void> {
  if (isTauriRuntime()) {
    await invoke("register_global_shortcut", { shortcut });
  }
}

export async function unregisterGlobalShortcut(): Promise<void> {
  if (isTauriRuntime()) {
    await invoke("unregister_global_shortcut");
  }
}

export async function readClipboardText(): Promise<string> {
  if (isTauriRuntime()) {
    return (await tauriReadClipboardText()) ?? "";
  }

  if (typeof navigator !== "undefined" && navigator.clipboard) {
    return navigator.clipboard.readText();
  }

  return "";
}

export async function writeClipboardText(text: string): Promise<void> {
  if (isTauriRuntime()) {
    await tauriWriteClipboardText(text);
    return;
  }

  if (typeof navigator !== "undefined" && navigator.clipboard) {
    await navigator.clipboard.writeText(text);
  }
}
