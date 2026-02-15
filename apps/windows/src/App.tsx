import { useEffect, useMemo, useState } from "react";
import {
  computeActionStats,
  suggestPrompt,
  type ExecutionLogEntry,
} from "../../../shared/core/src";
import {
  appendExecutionLog,
  checkPermissions,
  loadExecutionLogs,
  loadSetup,
  readClipboardText,
  registerGlobalShortcut,
  saveSetup,
  unregisterGlobalShortcut,
  writeClipboardText,
  type PermissionStatus,
} from "./platform";
import { t, type AppLanguage } from "./i18n";

type Provider = "OpenAI" | "Anthropic" | "OpenRouter" | "Perplexity" | "Groq";

const ACTION_ID = "first-action";
const LANGUAGE_KEY = "shortcutai_windows_language";

function loadLanguagePreference(): AppLanguage {
  const saved = localStorage.getItem(LANGUAGE_KEY);
  if (saved === "english" || saved === "japanese" || saved === "system") {
    return saved;
  }

  return "system";
}

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

  useEffect(() => {
    localStorage.setItem(LANGUAGE_KEY, language);
  }, [language]);

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

    return () => {
      mounted = false;
    };
  }, []);

  const stats = useMemo(() => computeActionStats(logs, ACTION_ID), [logs]);
  const autoSuggestion = useMemo(() => suggestPrompt(prompt, stats), [prompt, stats]);

  const canFinish =
    permissionGranted &&
    apiKey.trim().length > 0 &&
    actionName.trim().length > 0 &&
    prompt.trim().length > 0;

  const tr = (key: Parameters<typeof t>[1]) => t(language, key);

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

  return (
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
              <button onClick={() => void handleRegisterShortcut()}>{tr("registerShortcut")}</button>
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
              <button onClick={() => void handleCaptureClipboard()}>{tr("captureClipboard")}</button>
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
                {tr("successRate")} {Math.round(stats.successRate * 100)}% • {tr("avgLatency")} {" "}
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
  );
}
