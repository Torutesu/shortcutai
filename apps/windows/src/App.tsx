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
  type Action,
  type PermissionStatus,
  type Provider,
} from "./platform";
import { t, type AppLanguage } from "./i18n";

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
  | { phase: "running"; text: string; actionId: string }
  | { phase: "result"; originalText: string; result: string; actionName: string }
  | { phase: "error"; originalText: string; message: string };

// ---------------------------------------------------------------------------
// Action popup component
// ---------------------------------------------------------------------------

interface ActionPopupProps {
  state: PopupPhase;
  actions: Action[];
  onRun: (actionId: string, text: string) => void;
  onApply: (result: string) => void;
  onCopy: (result: string) => void;
  onClose: () => void;
  tr: (key: Parameters<typeof t>[1]) => string;
  copied: boolean;
}

function ActionPopup({
  state,
  actions,
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
  const resultActionName = state.phase === "result" ? state.actionName : "";
  const errorMessage = state.phase === "error" ? state.message : null;
  const isRunning = state.phase === "running";
  const runningActionId = state.phase === "running" ? state.actionId : null;

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
          <div className="popup-actions-list">
            {actions.map((action) => (
              <div key={action.id} className="popup-action-item">
                <span className="popup-action-name">{action.name}</span>
                <button
                  onClick={() => capturedText && onRun(action.id, capturedText)}
                  disabled={isRunning || !capturedText}
                  className={runningActionId === action.id ? "button-running" : ""}
                >
                  {runningActionId === action.id ? tr("popupRunning") : "▶ Run"}
                </button>
              </div>
            ))}
          </div>
        )}

        {result !== null && (
          <>
            <div className="popup-section">
              <label>
                {tr("popupResultLabel")} — {resultActionName}
              </label>
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
  const [actions, setActions] = useState<Action[]>([
    {
      id: crypto.randomUUID(),
      name: "Rewrite politely",
      prompt: "Rewrite the text in a polite and concise tone. Return only the rewritten text.",
      createdAt: new Date().toISOString(),
    },
  ]);
  const [defaultActionId, setDefaultActionId] = useState<string | undefined>(undefined);
  const [setupDone, setSetupDone] = useState(false);
  const [logs, setLogs] = useState<ExecutionLogEntry[]>([]);

  // Action popup state
  const [popup, setPopup] = useState<PopupPhase>({ phase: "idle" });
  const [copied, setCopied] = useState(false);

  // Editing state for actions
  const [editingActionId, setEditingActionId] = useState<string | null>(null);
  const [editName, setEditName] = useState("");
  const [editPrompt, setEditPrompt] = useState("");

  // Refs to hold the latest values inside the event listener closure.
  const providerRef = useRef(provider);
  const apiKeyRef = useRef(apiKey);
  const actionsRef = useRef(actions);

  useEffect(() => { providerRef.current = provider; }, [provider]);
  useEffect(() => { apiKeyRef.current = apiKey; }, [apiKey]);
  useEffect(() => { actionsRef.current = actions; }, [actions]);

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
        setActions(savedSetup.actions);
        setDefaultActionId(savedSetup.defaultActionId);
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

  const firstActionId = actions[0]?.id || "";
  const stats = useMemo(() => computeActionStats(logs, firstActionId), [logs, firstActionId]);
  const firstAction = actions[0];
  const autoSuggestion = useMemo(
    () => (firstAction ? suggestPrompt(firstAction.prompt, stats) : null),
    [firstAction, stats],
  );

  const canFinish =
    permissionGranted &&
    apiKey.trim().length > 0 &&
    actions.length > 0 &&
    actions.every((a) => a.name.trim().length > 0 && a.prompt.trim().length > 0);

  const tr = (key: Parameters<typeof t>[1]) => t(language, key);

  // -------------------------------------------------------------------------
  // Setup actions
  // -------------------------------------------------------------------------

  const finishSetup = async () => {
    if (!canFinish) return;
    await saveSetup({
      provider,
      apiKey,
      actions,
      defaultActionId,
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
    const firstActionLocal = actions[0];
    if (!firstActionLocal) return;

    const entry: ExecutionLogEntry = {
      id: crypto.randomUUID(),
      timestamp: new Date().toISOString(),
      actionId: firstActionLocal.id,
      actionName: firstActionLocal.name,
      prompt: firstActionLocal.prompt,
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
  // Action management
  // -------------------------------------------------------------------------

  const addAction = () => {
    const newAction: Action = {
      id: crypto.randomUUID(),
      name: "New Action",
      prompt: "Enter your prompt here.",
      createdAt: new Date().toISOString(),
    };
    setActions([...actions, newAction]);
    setEditingActionId(newAction.id);
    setEditName(newAction.name);
    setEditPrompt(newAction.prompt);
  };

  const startEdit = (action: Action) => {
    setEditingActionId(action.id);
    setEditName(action.name);
    setEditPrompt(action.prompt);
  };

  const saveEdit = () => {
    if (!editingActionId) return;
    setActions(
      actions.map((a) =>
        a.id === editingActionId
          ? { ...a, name: editName, prompt: editPrompt }
          : a,
      ),
    );
    setEditingActionId(null);
  };

  const cancelEdit = () => {
    setEditingActionId(null);
  };

  const deleteAction = (id: string) => {
    if (actions.length === 1) {
      alert("Cannot delete the last action. At least one action is required.");
      return;
    }
    setActions(actions.filter((a) => a.id !== id));
    if (editingActionId === id) {
      setEditingActionId(null);
    }
  };

  // -------------------------------------------------------------------------
  // Action popup handlers
  // -------------------------------------------------------------------------

  const runAction = async (actionId: string, text: string) => {
    const action = actionsRef.current.find((a) => a.id === actionId);
    if (!action) return;

    setPopup({ phase: "running", text, actionId });
    const start = Date.now();

    try {
      const result = await callAI(
        providerRef.current,
        apiKeyRef.current,
        action.prompt,
        text,
      );
      const durationMs = Date.now() - start;

      setPopup({ phase: "result", originalText: text, result, actionName: action.name });

      const entry: ExecutionLogEntry = {
        id: crypto.randomUUID(),
        timestamp: new Date().toISOString(),
        actionId: action.id,
        actionName: action.name,
        prompt: action.prompt,
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

      // Update last used timestamp
      setActions(
        actionsRef.current.map((a) =>
          a.id === actionId ? { ...a, lastUsedAt: new Date().toISOString() } : a,
        ),
      );
    } catch (error) {
      const durationMs = Date.now() - start;
      const message = String(error);

      setPopup({ phase: "error", originalText: text, message });

      const entry: ExecutionLogEntry = {
        id: crypto.randomUUID(),
        timestamp: new Date().toISOString(),
        actionId: action.id,
        actionName: action.name,
        prompt: action.prompt,
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
    await hideWindow();
    await new Promise((resolve) => setTimeout(resolve, 200));
    await pasteText(result);
    setPopup({ phase: "idle" });
  };

  const handleCopyResult = async (result: string) => {
    await writeClipboardText(result);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const closePopup = () => setPopup({ phase: "idle" });

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
        actions={actions}
        onRun={(actionId, text) => void runAction(actionId, text)}
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
            <div className="actions-manager">
              {actions.map((action) => (
                <div key={action.id} className="action-item">
                  {editingActionId === action.id ? (
                    <div className="action-edit-form">
                      <input
                        value={editName}
                        onChange={(e) => setEditName(e.target.value)}
                        placeholder="Action name"
                      />
                      <textarea
                        value={editPrompt}
                        onChange={(e) => setEditPrompt(e.target.value)}
                        rows={3}
                        placeholder="Prompt"
                      />
                      <div className="row buttons">
                        <button className="button-primary" onClick={saveEdit}>
                          Save
                        </button>
                        <button className="button-ghost" onClick={cancelEdit}>
                          Cancel
                        </button>
                      </div>
                    </div>
                  ) : (
                    <>
                      <div className="action-info">
                        <strong>{action.name}</strong>
                        <p className="action-prompt-preview">{action.prompt}</p>
                      </div>
                      <div className="action-controls">
                        <button className="button-secondary" onClick={() => startEdit(action)}>
                          Edit
                        </button>
                        <button
                          className="button-ghost"
                          onClick={() => deleteAction(action.id)}
                        >
                          Delete
                        </button>
                      </div>
                    </>
                  )}
                </div>
              ))}
              <button className="button-outline" onClick={addAction}>
                + Add Action
              </button>
            </div>
            <button
              disabled={!canFinish}
              onClick={() => void finishSetup()}
              style={{ marginTop: "12px" }}
            >
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

            {autoSuggestion && firstAction ? (
              <div className="suggestion">
                <h3>{tr("suggestion")}</h3>
                <p>{autoSuggestion.summary}</p>
                {autoSuggestion.suggestedPrompt ? (
                  <button
                    onClick={() => {
                      setEditingActionId(firstAction.id);
                      setEditName(firstAction.name);
                      setEditPrompt(autoSuggestion.suggestedPrompt!);
                    }}
                  >
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
