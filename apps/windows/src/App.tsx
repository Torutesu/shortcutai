import { useEffect, useMemo, useRef, useState } from "react";
import { listen } from "@tauri-apps/api/event";
import {
  computeActionStats,
  suggestPrompt,
  type ExecutionLogEntry,
} from "../../../shared/core/src";
import {
  appendExecutionLog,
  callAI,
  checkPermissions,
  hideWindow,
  loadExecutionLogs,
  loadSetup,
  pasteText,
  readClipboardText,
  registerGlobalShortcut,
  saveSetup,
  unregisterGlobalShortcut,
  writeClipboardText,
  type PermissionStatus,
  type Provider,
} from "./platform";
import { t, type AppLanguage } from "./i18n";

const ACTION_ID = "first-action";
const LANGUAGE_KEY = "shortcutai_windows_language";

function loadLanguagePreference(): AppLanguage {
  const saved = localStorage.getItem(LANGUAGE_KEY);
  if (saved === "english" || saved === "japanese" || saved === "system") {
    return saved;
  }
  return "system";
}

// ---------------------------------------------------------------------------
// Action popup state machine
// ---------------------------------------------------------------------------

type PopupPhase =
  | { phase: "idle" }
  | { phase: "captured"; text: string }
  | { phase: "running"; text: string }
  | { phase: "result"; originalText: string; result: string }
  | { phase: "error"; originalText: string; message: string };

// ---------------------------------------------------------------------------
// Action popup component
// ---------------------------------------------------------------------------

interface ActionPopupProps {
  state: PopupPhase;
  actionName: string;
  onRun: (text: string) => void;
  onApply: (result: string) => void;
  onCopy: (result: string) => void;
  onClose: () => void;
  tr: (key: Parameters<typeof t>[1]) => string;
  copied: boolean;
}

function ActionPopup({
  state,
  actionName,
  onRun,
  onApply,
  onCopy,
  onClose,
  tr,
  copied,
}: ActionPopupProps) {
  if (state.phase === "idle") return null;

  const capturedText =
    state.phase === "captured" || state.phase === "running"
      ? state.text
      : state.phase === "result" || state.phase === "error"
        ? state.originalText
        : "";

  const result = state.phase === "result" ? state.result : null;
  const errorMessage = state.phase === "error" ? state.message : null;
  const isRunning = state.phase === "running";

  return (
    <div className="popup-overlay" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className="popup">
        <header className="popup-header">
          <h2>{tr("popupTitle")}</h2>
          <button className="popup-close" onClick={onClose} aria-label="Close">
            ✕
          </button>
        </header>

        <div className="popup-section">
          <label>{tr("popupInputLabel")}</label>
          <div className="popup-text-box">
            {capturedText || <span className="muted">{tr("popupEmptyText")}</span>}
          </div>
        </div>

        {!result && !errorMessage && (
          <div className="popup-action-row">
            <span className="popup-action-name">{actionName}</span>
            <button
              onClick={() => capturedText && onRun(capturedText)}
              disabled={isRunning || !capturedText}
            >
              {isRunning ? tr("popupRunning") : "▶ Run"}
            </button>
          </div>
        )}

        {result !== null && (
          <>
            <div className="popup-section">
              <label>{tr("popupResultLabel")}</label>
              <div className="popup-text-box popup-result">{result}</div>
            </div>
            <div className="popup-buttons">
              <button className="button-primary" onClick={() => onApply(result)}>
                {tr("popupApply")}
              </button>
              <button className="button-secondary" onClick={() => onCopy(result)}>
                {copied ? tr("popupCopied") : tr("popupCopy")}
              </button>
              <button className="button-ghost" onClick={onClose}>
                {tr("popupClose")}
              </button>
            </div>
          </>
        )}

        {errorMessage !== null && (
          <>
            <div className="popup-section">
              <p className="warning">
                {tr("popupError")}: {errorMessage}
              </p>
            </div>
            <div className="popup-buttons">
              <button
                className="button-secondary"
                onClick={() => capturedText && onRun(capturedText)}
              >
                Retry
              </button>
              <button className="button-ghost" onClick={onClose}>
                {tr("popupClose")}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Main App
// ---------------------------------------------------------------------------

export function App() {
  const [language, setLanguage] = useState<AppLanguage>(loadLanguagePreference);
  const [permissionGranted, setPermissionGranted] = useState(false);
  const [permissionStatus, setPermissionStatus] = useState<PermissionStatus | null>(null);
  const [platformError, setPlatformError] = useState<string | null>(null);
  const [shortcut, setShortcut] = useState("Ctrl+Shift+T");
  const [shortcutRegistered, setShortcutRegistered] = useState(false);
  const [clipboardDraft, setClipboardDraft] = useState("");
  const [capturedClipboard, setCapturedClipboard] = useState("");
  const [provider, setProvider] = useState<Provider>("OpenAI");
  const [apiKey, setApiKey] = useState("");
  const [actionName, setActionName] = useState("Rewrite politely");
  const [prompt, setPrompt] = useState(
    "Rewrite the text in a polite and concise tone. Return only the rewritten text.",
  );
  const [setupDone, setSetupDone] = useState(false);
  const [logs, setLogs] = useState<ExecutionLogEntry[]>([]);

  // Action popup state
  const [popup, setPopup] = useState<PopupPhase>({ phase: "idle" });
  const [copied, setCopied] = useState(false);

  // Refs to hold the latest values inside the event listener closure.
  const providerRef = useRef(provider);
  const apiKeyRef = useRef(apiKey);
  const promptRef = useRef(prompt);
  const actionNameRef = useRef(actionName);
  useEffect(() => { providerRef.current = provider; }, [provider]);
  useEffect(() => { apiKeyRef.current = apiKey; }, [apiKey]);
  useEffect(() => { promptRef.current = prompt; }, [prompt]);
  useEffect(() => { actionNameRef.current = actionName; }, [actionName]);

  useEffect(() => {
    localStorage.setItem(LANGUAGE_KEY, language);
  }, [language]);

  // Bootstrap: load saved setup, logs, and permissions.
  useEffect(() => {
    let mounted = true;

    async function bootstrap(): Promise<void> {
      const [status, savedSetup, savedLogs] = await Promise.all([
        checkPermissions(),
        loadSetup(),
        loadExecutionLogs(),
      ]);

      if (!mounted) return;

      setPermissionStatus(status);
      setPermissionGranted(status.globalShortcutReady && status.clipboardReady);
      setLogs(savedLogs);

      if (savedSetup) {
        setProvider(savedSetup.provider as Provider);
        setApiKey(savedSetup.apiKey);
        setActionName(savedSetup.actionName);
        setPrompt(savedSetup.prompt);
        setSetupDone(true);
      }
    }

    bootstrap().catch(() => {
      if (!mounted) return;
      setPermissionStatus({
        globalShortcutReady: false,
        clipboardReady: false,
        note: "Failed to load setup state.",
      });
    });

    return () => { mounted = false; };
  }, []);

  // Listen for the text-captured event emitted by the Rust backend when the
  // global shortcut fires.
  useEffect(() => {
    let unlisten: (() => void) | null = null;

    listen<string>("text-captured", (event) => {
      const text = event.payload ?? "";
      setPopup({ phase: "captured", text });
    })
      .then((fn) => { unlisten = fn; })
      .catch(() => {});

    return () => { unlisten?.(); };
  }, []);

  const stats = useMemo(() => computeActionStats(logs, ACTION_ID), [logs]);
  const autoSuggestion = useMemo(() => suggestPrompt(prompt, stats), [prompt, stats]);

  const canFinish =
    permissionGranted &&
    apiKey.trim().length > 0 &&
    actionName.trim().length > 0 &&
    prompt.trim().length > 0;

  const tr = (key: Parameters<typeof t>[1]) => t(language, key);

  // -------------------------------------------------------------------------
  // Setup actions
  // -------------------------------------------------------------------------

  const finishSetup = async () => {
    if (!canFinish) return;
    await saveSetup({
      provider,
      apiKey,
      actionName,
      prompt,
      setupCompletedAt: new Date().toISOString(),
    });
    setSetupDone(true);
  };

  const refreshPermissions = async () => {
    try {
      setPlatformError(null);
      const status = await checkPermissions();
      setPermissionStatus(status);
      setPermissionGranted(status.globalShortcutReady && status.clipboardReady);
    } catch (error) {
      setPlatformError(String(error));
    }
  };

  const handleRegisterShortcut = async () => {
    try {
      setPlatformError(null);
      await registerGlobalShortcut(shortcut.trim());
      setShortcutRegistered(true);
      setPermissionGranted(true);
    } catch (error) {
      setPlatformError(String(error));
      setShortcutRegistered(false);
    }
  };

  const handleUnregisterShortcut = async () => {
    try {
      setPlatformError(null);
      await unregisterGlobalShortcut();
      setShortcutRegistered(false);
    } catch (error) {
      setPlatformError(String(error));
    }
  };

  const handleCaptureClipboard = async () => {
    try {
      setPlatformError(null);
      const text = await readClipboardText();
      setCapturedClipboard(text);
    } catch (error) {
      setPlatformError(String(error));
    }
  };

  const handleCopyClipboard = async () => {
    try {
      setPlatformError(null);
      await writeClipboardText(clipboardDraft);
    } catch (error) {
      setPlatformError(String(error));
    }
  };

  const appendLog = async (success: boolean) => {
    const errorMessage = success ? null : "Network issue during request.";
    const entry: ExecutionLogEntry = {
      id: crypto.randomUUID(),
      timestamp: new Date().toISOString(),
      actionId: ACTION_ID,
      actionName,
      prompt,
      provider,
      modelId: success ? "gpt-4o-mini" : "web-search",
      durationMs: success ? 1200 + Math.random() * 2000 : 9000 + Math.random() * 5000,
      inputLength: 160,
      outputLength: success ? 145 : 0,
      success,
      errorMessage,
    };
    const nextLogs = await appendExecutionLog(entry);
    setLogs(nextLogs);
  };

  // -------------------------------------------------------------------------
  // Action popup handlers
  // -------------------------------------------------------------------------

  const runAction = async (text: string) => {
    setPopup({ phase: "running", text });
    const start = Date.now();

    try {
      const result = await callAI(
        providerRef.current,
        apiKeyRef.current,
        promptRef.current,
        text,
      );
      const durationMs = Date.now() - start;

      setPopup({ phase: "result", originalText: text, result });

      const entry: ExecutionLogEntry = {
        id: crypto.randomUUID(),
        timestamp: new Date().toISOString(),
        actionId: ACTION_ID,
        actionName: actionNameRef.current,
        prompt: promptRef.current,
        provider: providerRef.current,
        modelId: null,
        durationMs,
        inputLength: text.length,
        outputLength: result.length,
        success: true,
        errorMessage: null,
      };
      const nextLogs = await appendExecutionLog(entry);
      setLogs(nextLogs);
    } catch (error) {
      const durationMs = Date.now() - start;
      const message = String(error);

      setPopup({ phase: "error", originalText: text, message });

      const entry: ExecutionLogEntry = {
        id: crypto.randomUUID(),
        timestamp: new Date().toISOString(),
        actionId: ACTION_ID,
        actionName: actionNameRef.current,
        prompt: promptRef.current,
        provider: providerRef.current,
        modelId: null,
        durationMs,
        inputLength: text.length,
        outputLength: 0,
        success: false,
        errorMessage: message,
      };
      const nextLogs = await appendExecutionLog(entry);
      setLogs(nextLogs);
    }
  };

  const handleApply = async (result: string) => {
    // Hide our window so the original app regains focus, then paste.
    await hideWindow();
    await pasteText(result);
    setPopup({ phase: "idle" });
  };

  const handleCopyResult = async (result: string) => {
    await writeClipboardText(result);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const closePopup = () => setPopup({ phase: "idle" });

  // In browser preview: manually trigger the popup with the draft text.
  const simulateShortcut = () => {
    setPopup({
      phase: "captured",
      text: clipboardDraft || "Hello, this is a test sentence.",
    });
  };

  // -------------------------------------------------------------------------
  // Render
  // -------------------------------------------------------------------------

  return (
    <>
      <ActionPopup
        state={popup}
        actionName={actionName}
        onRun={(text) => void runAction(text)}
        onApply={(result) => void handleApply(result)}
        onCopy={(result) => void handleCopyResult(result)}
        onClose={closePopup}
        tr={tr}
        copied={copied}
      />

      <main className="page">
        <section className="panel">
          <header className="header">
            <h1>{tr("title")}</h1>
            <p>{tr("subtitle")}</p>
            <div className="row">
              <label>{tr("language")}</label>
              <select
                value={language}
                onChange={(event) => setLanguage(event.target.value as AppLanguage)}
              >
                <option value="system">{tr("system")}</option>
                <option value="english">{tr("english")}</option>
                <option value="japanese">{tr("japanese")}</option>
              </select>
            </div>
          </header>

          <div className="card">
            <h2>{tr("step1")}</h2>
            <p>{tr("step1Desc")}</p>
            <label className="checkbox">
              <input
                type="checkbox"
                checked={permissionGranted}
                onChange={(event) => setPermissionGranted(event.target.checked)}
              />
              {tr("permissionGranted")}
            </label>
            <div className="row buttons">
              <button onClick={() => void refreshPermissions()}>{tr("refreshPermissions")}</button>
            </div>
            {permissionStatus?.note ? (
              <p className="warning">
                {tr("permissionStatus")}: {permissionStatus.note}
              </p>
            ) : null}

            <div className="grid top-gap">
              <label>{tr("globalShortcut")}</label>
              <input value={shortcut} onChange={(event) => setShortcut(event.target.value)} />
              <div className="row buttons">
                <button onClick={() => void handleRegisterShortcut()}>
                  {tr("registerShortcut")}
                </button>
                <button onClick={() => void handleUnregisterShortcut()}>
                  {tr("unregisterShortcut")}
                </button>
              </div>
              <p className="muted">
                {shortcutRegistered ? tr("shortcutRegistered") : tr("shortcutUnregistered")}
              </p>

              <label>{tr("clipboard")}</label>
              <textarea
                value={clipboardDraft}
                onChange={(event) => setClipboardDraft(event.target.value)}
                rows={2}
                placeholder={tr("clipboardPlaceholder")}
              />
              <div className="row buttons">
                <button onClick={() => void handleCopyClipboard()}>{tr("copyToClipboard")}</button>
                <button onClick={() => void handleCaptureClipboard()}>
                  {tr("captureClipboard")}
                </button>
                <button className="button-outline" onClick={simulateShortcut}>
                  {tr("popupSimulate")}
                </button>
              </div>
              {capturedClipboard ? <p className="mono">{capturedClipboard}</p> : null}
              {platformError ? <p className="warning">{platformError}</p> : null}
            </div>
          </div>

          <div className="card">
            <h2>{tr("step2")}</h2>
            <div className="grid">
              <label>{tr("provider")}</label>
              <select
                value={provider}
                onChange={(event) => setProvider(event.target.value as Provider)}
              >
                <option>OpenAI</option>
                <option>Anthropic</option>
                <option>OpenRouter</option>
                <option>Perplexity</option>
                <option>Groq</option>
              </select>
              <label>{tr("apiKey")}</label>
              <input
                value={apiKey}
                onChange={(event) => setApiKey(event.target.value)}
                placeholder="sk-..."
                type="password"
              />
            </div>
          </div>

          <div className="card">
            <h2>{tr("step3")}</h2>
            <div className="grid">
              <label>{tr("actionName")}</label>
              <input
                value={actionName}
                onChange={(event) => setActionName(event.target.value)}
              />
              <label>{tr("prompt")}</label>
              <textarea
                value={prompt}
                onChange={(event) => setPrompt(event.target.value)}
                rows={4}
              />
            </div>
            <button disabled={!canFinish} onClick={() => void finishSetup()}>
              {tr("finishSetup")}
            </button>
            {setupDone ? <p className="ok">{tr("setupSaved")}</p> : null}
          </div>

          <div className="card">
            <h2>{tr("insights")}</h2>
            <div className="row buttons">
              <button onClick={() => void appendLog(true)}>{tr("runSuccess")}</button>
              <button onClick={() => void appendLog(false)}>{tr("runFailure")}</button>
            </div>

            {!stats ? (
              <p>{tr("noLogs")}</p>
            ) : (
              <>
                <p>
                  {tr("successRate")} {Math.round(stats.successRate * 100)}% • {tr("avgLatency")}{" "}
                  {Math.round(stats.averageDurationMs)}ms • {tr("runs")} {stats.totalRuns}
                </p>
                {stats.topFailureReasons.length > 0 ? (
                  <p>
                    {tr("topFailures")}: {stats.topFailureReasons.join(" / ")}
                  </p>
                ) : null}
              </>
            )}

            {autoSuggestion ? (
              <div className="suggestion">
                <h3>{tr("suggestion")}</h3>
                <p>{autoSuggestion.summary}</p>
                {autoSuggestion.suggestedPrompt ? (
                  <button onClick={() => setPrompt(autoSuggestion.suggestedPrompt!)}>
                    {tr("applySuggestion")}
                  </button>
                ) : null}
              </div>
            ) : null}
          </div>
        </section>
      </main>
    </>
  );
}
