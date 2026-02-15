//
//  SetupWizardView.swift
//  typo
//

import SwiftUI
import AppKit

struct SetupWizardView: View {
    @StateObject private var store = ActionsStore.shared
    @State private var hasAccessibilityPermission = AXIsProcessTrusted()
    @State private var selectedProvider: AIProvider = .openai
    @State private var apiKeyInput: String = ""
    @State private var firstActionName: String = ""
    @State private var firstActionPrompt: String = ""
    @State private var isSaving = false

    var onComplete: () -> Void

    private var canComplete: Bool {
        hasAccessibilityPermission &&
        !apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !firstActionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !firstActionPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "F7F7FA"),
                    Color(hex: "EEF6FF")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text("Setup ShortcutAI")
                    .font(.custom("Nunito-Black", size: 34))
                    .foregroundColor(Color(hex: "1a1a1a"))

                Text("Complete onboarding in one screen.")
                    .font(.nunitoRegularBold(size: 14))
                    .foregroundColor(.secondary)

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        setupCard(
                            step: "1",
                            title: "Accessibility Check",
                            subtitle: hasAccessibilityPermission ? "Permission granted." : "Grant accessibility to enable global shortcuts."
                        ) {
                            HStack {
                                PermissionPill(text: hasAccessibilityPermission ? "Granted" : "Not Granted", isGranted: hasAccessibilityPermission)
                                Spacer()
                                Button(String(localized: "Refresh Status")) {
                                    hasAccessibilityPermission = AXIsProcessTrusted()
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.gray.opacity(0.12))
                                )

                                Button(String(localized: "Open Settings")) {
                                    openAccessibilitySettings()
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color(red: 0.0, green: 0.584, blue: 1.0))
                                )
                            }
                        }

                        setupCard(
                            step: "2",
                            title: "API Key Setup",
                            subtitle: "Pick a provider and add your API key."
                        ) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Provider")
                                        .font(.nunitoRegularBold(size: 13))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Picker("", selection: $selectedProvider) {
                                        ForEach(AIProvider.allCases, id: \.self) { provider in
                                            Text(provider.rawValue).tag(provider)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .labelsHidden()
                                }

                                SecureField(selectedProvider.apiKeyPlaceholder, text: $apiKeyInput)
                                    .textFieldStyle(.plain)
                                    .font(.nunitoRegularBold(size: 14))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }

                        setupCard(
                            step: "3",
                            title: "Create Your First Action",
                            subtitle: "Define one action you can run right away."
                        ) {
                            VStack(alignment: .leading, spacing: 10) {
                                TextField("Action Name (e.g. Rewrite politely)", text: $firstActionName)
                                    .textFieldStyle(.plain)
                                    .font(.nunitoRegularBold(size: 14))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )

                                ZStack(alignment: .topLeading) {
                                    if firstActionPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Text("Prompt (e.g. Rewrite the text clearly and return only the rewritten text.)")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary.opacity(0.8))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                    }

                                    TextEditor(text: $firstActionPrompt)
                                        .font(.nunitoRegularBold(size: 14))
                                        .scrollContentBackground(.hidden)
                                        .background(Color.clear)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                }
                                .frame(height: 100)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(.top, 4)
                }

                Button(action: completeSetup) {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.7)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text("Finish Setup")
                            .font(.nunitoBold(size: 15))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(canComplete ? Color(red: 0.0, green: 0.584, blue: 1.0) : Color.gray.opacity(0.4))
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canComplete || isSaving)
            }
            .padding(24)
            .frame(maxWidth: 760, maxHeight: 480, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 8)
            )
            .padding(20)
        }
        .onAppear {
            selectedProvider = store.selectedProvider
            apiKeyInput = store.apiKey(for: selectedProvider)
            hasAccessibilityPermission = AXIsProcessTrusted()
        }
    }

    private func completeSetup() {
        guard canComplete else { return }
        isSaving = true

        store.saveProvider(selectedProvider)
        store.saveApiKey(apiKeyInput, for: selectedProvider)

        let name = firstActionName.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = firstActionPrompt.trimmingCharacters(in: .whitespacesAndNewlines)

        let action = Action(
            name: name,
            icon: "sparkles",
            prompt: prompt,
            shortcut: ""
        )
        store.addAction(action)

        OnboardingManager.shared.completeOnboarding()
        isSaving = false
        onComplete()
    }

    @ViewBuilder
    private func setupCard(step: String, title: String, subtitle: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(step)
                    .font(.nunitoBold(size: 13))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(Color(red: 0.0, green: 0.584, blue: 1.0))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(title))
                        .font(.nunitoBold(size: 16))
                        .foregroundColor(.primary)
                    Text(LocalizedStringKey(subtitle))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(NSColor.windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.gray.opacity(0.16), lineWidth: 1)
                )
        )
    }
}

private struct PermissionPill: View {
    let text: String
    let isGranted: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 11))
            Text(LocalizedStringKey(text))
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(isGranted ? Color(hex: "137333") : Color(hex: "A31515"))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isGranted ? Color(hex: "E6F4EA") : Color(hex: "FCE8E6"))
        )
    }
}
