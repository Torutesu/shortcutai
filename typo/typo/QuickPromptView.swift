//
//  QuickPromptView.swift
//  typo
//
//  Quick Prompt - run a one-off AI prompt on selected text
//

import SwiftUI

struct QuickPromptView: View {
    @StateObject private var textManager = CapturedTextManager.shared
    @State private var promptText: String = ""
    @FocusState private var isPromptFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("appTheme") private var appTheme: String = "System"

    var onClose: () -> Void

    private var savedColorScheme: ColorScheme? {
        switch appTheme {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }

    private var appBlue: Color {
        Color(red: 0.0, green: 0.584, blue: 1.0)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Quick Prompt")
                    .font(.nunitoRegularBold(size: 14))
                    .foregroundColor(.primary)

                Spacer()

                Button(action: { onClose() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Custom prompt input
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.orange)
                    .frame(width: 18)

                TextField("Write your prompt...", text: $promptText)
                    .textFieldStyle(.plain)
                    .font(.nunitoRegularBold(size: 14))
                    .foregroundColor(.primary)
                    .focused($isPromptFocused)

                if !promptText.isEmpty {
                    Image(systemName: "return")
                        .foregroundColor(.gray)
                        .font(.system(size: 12))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            // Selected text preview
            ScrollView {
                Text(textManager.capturedText)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            }
            .frame(maxHeight: 200)
            .background(Color(NSColor.controlBackgroundColor))

            // Footer
            HStack {
                HStack(spacing: 4) {
                    KeyboardKey("esc")
                    Text("close")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    KeyboardKey("↵")
                    Text("run")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 320)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        .preferredColorScheme(savedColorScheme)
        .onAppear {
            isPromptFocused = true
        }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
        .onKeyPress(.return) {
            executeQuickPrompt()
            return .handled
        }
    }

    func executeQuickPrompt() {
        let prompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        let quickAction = Action(
            name: "Quick Prompt",
            icon: "bolt.fill",
            prompt: prompt,
            shortcut: "",
            shortcutModifiers: []
        )

        promptText = ""
        onClose()

        globalAppDelegate?.pendingAction = quickAction
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            globalAppDelegate?.showPopoverWithAction()
        }
    }
}
