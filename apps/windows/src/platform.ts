import { invoke } from "@tauri-apps/api/tauri";
import {
  readText as tauriReadClipboardText,
  writeText as tauriWriteClipboardText,
} from "@tauri-apps/api/clipboard";
import type { ExecutionLogEntry } from "../../../shared/core/src";

export interface Action {
  id: string;
  name: string;
  prompt: string;
  createdAt: string;
  lastUsedAt?: string;
}

export interface SetupPayload {
  provider: string;
  apiKey: string;
  actions: Action[];
  defaultActionId?: string;
  setupCompletedAt: string;
}

// Legacy format (backward compatibility)
interface LegacySetupPayload {
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

function migrateSetup(raw: SetupPayload | LegacySetupPayload): SetupPayload {
  // Check if it's legacy format (has actionName instead of actions array)
  if ("actionName" in raw && "prompt" in raw && !("actions" in raw)) {
    const legacy = raw as LegacySetupPayload;
    const action: Action = {
      id: crypto.randomUUID(),
      name: legacy.actionName,
      prompt: legacy.prompt,
      createdAt: legacy.setupCompletedAt,
    };
    return {
      provider: legacy.provider,
      apiKey: legacy.apiKey,
      actions: [action],
      defaultActionId: action.id,
      setupCompletedAt: legacy.setupCompletedAt,
    };
  }
  return raw as SetupPayload;
}

export async function loadSetup(): Promise<SetupPayload | null> {
  let setup: SetupPayload | LegacySetupPayload | null = null;

  if (isTauriRuntime()) {
    try {
      setup = await invoke<SetupPayload | null>("load_setup");
    } catch {
      return null;
    }
  } else {
    setup = parseJson<SetupPayload | LegacySetupPayload>(localStorage.getItem(SETUP_KEY));
  }

  return setup ? migrateSetup(setup) : null;
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

/**
 * Write `text` to the clipboard and simulate Ctrl+V in the previously-focused
 * application.  On Tauri, this is handled natively in Rust; in browser preview,
 * it just copies to clipboard.
 */
export async function pasteText(text: string): Promise<void> {
  if (isTauriRuntime()) {
    await invoke("paste_text", { text });
    return;
  }

  // Browser preview: just write to clipboard as a best-effort.
  if (typeof navigator !== "undefined" && navigator.clipboard) {
    await navigator.clipboard.writeText(text);
  }
}

/**
 * Hide the main application window so the target app regains focus before we
 * simulate Ctrl+V.
 */
export async function hideWindow(): Promise<void> {
  if (isTauriRuntime()) {
    await invoke("hide_window");
  }
}

// ---------------------------------------------------------------------------
// AI provider integration
// ---------------------------------------------------------------------------

export type Provider = "OpenAI" | "Anthropic" | "OpenRouter" | "Perplexity" | "Groq";

interface ChatMessage {
  role: "system" | "user" | "assistant";
  content: string;
}

interface OpenAICompatibleResponse {
  choices: Array<{ message: { content: string } }>;
}

interface AnthropicResponse {
  content: Array<{ type: string; text: string }>;
}

/** Model IDs used per provider. */
const DEFAULT_MODELS: Record<Provider, string> = {
  OpenAI: "gpt-4o-mini",
  Anthropic: "claude-haiku-4-5-20251001",
  OpenRouter: "openai/gpt-4o-mini",
  Perplexity: "llama-3.1-sonar-small-128k-online",
  Groq: "llama-3.1-8b-instant",
};

async function callOpenAICompatible(
  baseUrl: string,
  apiKey: string,
  model: string,
  messages: ChatMessage[],
  extraHeaders: Record<string, string> = {},
): Promise<string> {
  const response = await fetch(`${baseUrl}/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
      ...extraHeaders,
    },
    body: JSON.stringify({ model, messages, max_tokens: 2048 }),
  });

  if (!response.ok) {
    const body = await response.text().catch(() => "");
    throw new Error(`${response.status} ${response.statusText}: ${body}`);
  }

  const data = (await response.json()) as OpenAICompatibleResponse;
  return data.choices[0]?.message?.content ?? "";
}

async function callAnthropic(
  apiKey: string,
  model: string,
  systemPrompt: string,
  userText: string,
): Promise<string> {
  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model,
      max_tokens: 2048,
      system: systemPrompt,
      messages: [{ role: "user", content: userText }],
    }),
  });

  if (!response.ok) {
    const body = await response.text().catch(() => "");
    throw new Error(`${response.status} ${response.statusText}: ${body}`);
  }

  const data = (await response.json()) as AnthropicResponse;
  return data.content.find((c) => c.type === "text")?.text ?? "";
}

/**
 * Call the configured AI provider with the action prompt and selected text.
 * Returns the transformed text.
 */
export async function callAI(
  provider: Provider,
  apiKey: string,
  actionPrompt: string,
  selectedText: string,
): Promise<string> {
  const model = DEFAULT_MODELS[provider];

  if (provider === "Anthropic") {
    return callAnthropic(apiKey, model, actionPrompt, selectedText);
  }

  const baseUrls: Record<Exclude<Provider, "Anthropic">, string> = {
    OpenAI: "https://api.openai.com/v1",
    OpenRouter: "https://openrouter.ai/api/v1",
    Perplexity: "https://api.perplexity.ai",
    Groq: "https://api.groq.com/openai/v1",
  };

  const messages: ChatMessage[] = [
    { role: "system", content: actionPrompt },
    { role: "user", content: selectedText },
  ];

  return callOpenAICompatible(
    baseUrls[provider as Exclude<Provider, "Anthropic">],
    apiKey,
    model,
    messages,
  );
}
