import type {
  ActionExecutionStats,
  ExecutionLogEntry,
  PromptAutoSuggestion,
} from "./types";

function normalizeFailureReason(message?: string | null): string {
  const raw = (message ?? "Unknown failure").toLowerCase();
  if (raw.includes("no text selected")) return "No input text was selected.";
  if (raw.includes("api key")) return "API key was missing or invalid.";
  if (raw.includes("timeout")) return "The request timed out.";
  if (raw.includes("network")) return "Network issue during request.";
  return message ?? "Unknown failure.";
}

export function computeActionStats(
  entries: ExecutionLogEntry[],
  actionId: string,
): ActionExecutionStats | null {
  const filtered = entries.filter((entry) => entry.actionId === actionId);
  if (filtered.length === 0) return null;

  const successfulRuns = filtered.filter((entry) => entry.success).length;
  const failedRuns = filtered.length - successfulRuns;
  const successRate = successfulRuns / filtered.length;
  const averageDurationMs =
    filtered.reduce((sum, entry) => sum + entry.durationMs, 0) / filtered.length;

  const buckets = new Map<string, number>();
  filtered
    .filter((entry) => !entry.success)
    .forEach((entry) => {
      const reason = normalizeFailureReason(entry.errorMessage);
      buckets.set(reason, (buckets.get(reason) ?? 0) + 1);
    });

  const topFailureReasons = [...buckets.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3)
    .map(([reason]) => reason);

  return {
    totalRuns: filtered.length,
    successfulRuns,
    failedRuns,
    successRate,
    averageDurationMs,
    topFailureReasons,
  };
}

function buildReliablePrompt(prompt: string, failureReasons: string[]): string {
  const reasons = failureReasons.length
    ? `\nKnown failure patterns to avoid:\n- ${failureReasons.join("\n- ")}`
    : "";

  return `${prompt}

Requirements:
- Return only the transformed text.
- Do not include explanations, markdown, or quotes.
- If input is ambiguous, still return a best-effort transformed result.
- Preserve original intent and key facts.${reasons}`;
}

function buildFastPrompt(prompt: string): string {
  return `${prompt}

Requirements:
- Be concise and direct.
- Prefer one clear output with minimal verbosity.
- Avoid extra analysis unless explicitly requested.`;
}

export function suggestPrompt(
  currentPrompt: string,
  stats: ActionExecutionStats | null,
): PromptAutoSuggestion | null {
  if (!stats || stats.totalRuns < 5) return null;

  const successRatePercent = Math.round(stats.successRate * 100);
  if (stats.successRate < 0.7) {
    return {
      summary: `Success rate is ${successRatePercent}% across ${stats.totalRuns} runs. Clarify output constraints and fallback behavior.`,
      suggestedPrompt: buildReliablePrompt(currentPrompt, stats.topFailureReasons),
    };
  }

  if (stats.averageDurationMs > 10_000) {
    return {
      summary: `Average response time is ${Math.round(stats.averageDurationMs)}ms. Tighten scope for faster responses.`,
      suggestedPrompt: buildFastPrompt(currentPrompt),
    };
  }

  return null;
}
