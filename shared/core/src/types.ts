export interface ExecutionLogEntry {
  id: string;
  timestamp: string;
  actionId: string;
  actionName: string;
  prompt: string;
  provider?: string | null;
  modelId?: string | null;
  durationMs: number;
  inputLength: number;
  outputLength: number;
  success: boolean;
  errorMessage?: string | null;
}

export interface ActionExecutionStats {
  totalRuns: number;
  successfulRuns: number;
  failedRuns: number;
  successRate: number;
  averageDurationMs: number;
  topFailureReasons: string[];
}

export interface PromptAutoSuggestion {
  summary: string;
  suggestedPrompt?: string;
}
