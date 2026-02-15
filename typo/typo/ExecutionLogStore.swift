//
//  ExecutionLogStore.swift
//  typo
//

import Foundation

struct ExecutionLogEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let actionId: UUID
    let actionName: String
    let prompt: String
    let provider: String?
    let modelId: String?
    let durationMs: Double
    let inputLength: Int
    let outputLength: Int
    let success: Bool
    let errorMessage: String?
}

struct ActionExecutionStats {
    let totalRuns: Int
    let successfulRuns: Int
    let failedRuns: Int
    let successRate: Double
    let averageDurationMs: Double
    let topFailureReasons: [String]
}

struct PromptAutoSuggestion {
    let summary: String
    let suggestedPrompt: String?
}

final class ExecutionLogStore: ObservableObject {
    static let shared = ExecutionLogStore()

    @Published private(set) var entries: [ExecutionLogEntry] = []

    private let maxEntries = 2000
    private let fileName = "execution_logs.json"

    private lazy var logFileURL: URL = {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let dir = base.appendingPathComponent("ShortcutAI", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }()

    private init() {
        load()
    }

    func record(
        action: Action,
        prompt: String,
        provider: String?,
        modelId: String?,
        startedAt: Date,
        input: String,
        output: String?,
        success: Bool,
        errorMessage: String?
    ) {
        let elapsed = Date().timeIntervalSince(startedAt) * 1000
        let entry = ExecutionLogEntry(
            id: UUID(),
            timestamp: Date(),
            actionId: action.id,
            actionName: action.name,
            prompt: prompt,
            provider: provider,
            modelId: modelId,
            durationMs: max(0, elapsed),
            inputLength: input.count,
            outputLength: output?.count ?? 0,
            success: success,
            errorMessage: errorMessage
        )

        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        save()
    }

    func stats(for actionId: UUID) -> ActionExecutionStats? {
        let filtered = entries.filter { $0.actionId == actionId }
        guard !filtered.isEmpty else { return nil }

        let successCount = filtered.filter(\.success).count
        let failed = filtered.filter { !$0.success }
        let failedCount = failed.count
        let successRate = Double(successCount) / Double(filtered.count)
        let averageDuration = filtered.map(\.durationMs).reduce(0, +) / Double(filtered.count)

        var failureBuckets: [String: Int] = [:]
        for failure in failed {
            let reason = normalizedFailureReason(failure.errorMessage)
            failureBuckets[reason, default: 0] += 1
        }

        let topFailureReasons = failureBuckets
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map(\.key)

        return ActionExecutionStats(
            totalRuns: filtered.count,
            successfulRuns: successCount,
            failedRuns: failedCount,
            successRate: successRate,
            averageDurationMs: averageDuration,
            topFailureReasons: topFailureReasons
        )
    }

    func autoSuggestion(for action: Action) -> PromptAutoSuggestion? {
        guard let stats = stats(for: action.id), stats.totalRuns >= 5 else {
            return nil
        }

        let successRatePercent = Int((stats.successRate * 100).rounded())

        if stats.successRate < 0.7 {
            let format = String(localized: "Success rate summary format")
            let summary = String(format: format, successRatePercent, stats.totalRuns)
            return PromptAutoSuggestion(
                summary: summary,
                suggestedPrompt: buildReliablePrompt(from: action.prompt, failureReasons: stats.topFailureReasons)
            )
        }

        if stats.averageDurationMs > 10_000 {
            let format = String(localized: "Average response summary format")
            let summary = String(format: format, Int(stats.averageDurationMs.rounded()))
            return PromptAutoSuggestion(
                summary: summary,
                suggestedPrompt: buildFastPrompt(from: action.prompt)
            )
        }

        return nil
    }

    private func normalizedFailureReason(_ message: String?) -> String {
        let raw = (message ?? "Unknown failure").lowercased()
        if raw.contains("no text selected") {
            return String(localized: "No input text was selected.")
        }
        if raw.contains("api key") {
            return String(localized: "API key was missing or invalid.")
        }
        if raw.contains("timeout") {
            return String(localized: "The request timed out.")
        }
        if raw.contains("network") {
            return String(localized: "Network issue during request.")
        }
        return message ?? String(localized: "Unknown failure.")
    }

    private func buildReliablePrompt(from prompt: String, failureReasons: [String]) -> String {
        let reasons = failureReasons.isEmpty
            ? ""
            : "\nKnown failure patterns to avoid:\n- " + failureReasons.joined(separator: "\n- ")

        return """
        \(prompt)

        Requirements:
        - Return only the transformed text.
        - Do not include explanations, markdown, or quotes.
        - If input is ambiguous, still return a best-effort transformed result.
        - Preserve original intent and key facts.\(reasons)
        """
    }

    private func buildFastPrompt(from prompt: String) -> String {
        return """
        \(prompt)

        Requirements:
        - Be concise and direct.
        - Prefer one clear output with minimal verbosity.
        - Avoid extra analysis unless explicitly requested.
        """
    }

    private func load() {
        guard let data = try? Data(contentsOf: logFileURL) else { return }
        guard let decoded = try? JSONDecoder().decode([ExecutionLogEntry].self, from: data) else { return }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: logFileURL, options: .atomic)
    }
}
