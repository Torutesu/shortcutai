//
//  SettingsView.swift
//  typo
//

import SwiftUI
import AppKit

// MARK: - Helper Function

func openAccessibilitySettings() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
        NSWorkspace.shared.open(url)
    }
}

struct SettingsView: View {
    @StateObject private var store = ActionsStore.shared
    @State private var selectedTab = 1
    @State private var selectedAction: Action?

    var body: some View {
        TabView(selection: $selectedTab) {
            // General Tab
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(0)

            // Actions Tab
            ActionsSettingsView(selectedAction: $selectedAction)
                .tabItem {
                    Label("Actions", systemImage: "list.bullet")
                }
                .tag(1)

            // About Tab
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(2)
        }
        .frame(width: 600, height: 450)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @StateObject private var store = ActionsStore.shared
    @State private var apiKeyInput: String = ""
    @State private var launchAtLogin = false
    @State private var selectedProvider: AIProvider = .openai

    var body: some View {
        Form {
            Section {
                Picker("AI Provider", selection: $selectedProvider) {
                    ForEach(AIProvider.allCases, id: \.self) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedProvider) { _, newValue in
                    store.saveProvider(newValue)
                }
                .onAppear {
                    selectedProvider = store.selectedProvider
                }

                SecureField("API Key", text: $apiKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .onAppear {
                        apiKeyInput = store.apiKey
                    }
                    .onChange(of: apiKeyInput) { _, newValue in
                        store.saveApiKey(newValue)
                    }

                Text("Get your API key from \(selectedProvider.websiteURL)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("API Configuration")
            }

            Section {
                HStack {
                    Text("Global Shortcut")
                    Spacer()
                    Text("⌘ + ⇧ + T")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                Toggle("Launch at Login", isOn: $launchAtLogin)
            } header: {
                Text("Preferences")
            }

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Accessibility Permission")
                            .font(.body)
                        Text("Required for global keyboard shortcuts to work")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("Open Settings") {
                        openAccessibilitySettings()
                    }
                }
            } header: {
                Text("Permissions")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Actions Settings

struct ActionsSettingsView: View {
    @StateObject private var store = ActionsStore.shared
    @Binding var selectedAction: Action?

    var body: some View {
        HSplitView {
            // Sidebar - Actions list
            VStack(alignment: .leading, spacing: 0) {
                List(selection: $selectedAction) {
                    ForEach(store.actions) { action in
                        HStack(spacing: 10) {
                            Image(systemName: action.icon)
                                .foregroundColor(.accentColor)
                                .frame(width: 20)
                            Text(action.name)
                        }
                        .tag(action)
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.sidebar)

                Divider()

                HStack {
                    Button(action: addNewAction) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)

                    Button(action: deleteSelectedAction) {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.borderless)
                    .disabled(selectedAction == nil)

                    Spacer()
                }
                .padding(8)
            }
            .frame(minWidth: 180, maxWidth: 200)

            // Editor
            if let action = selectedAction {
                ActionEditorView(action: action) { updatedAction in
                    store.updateAction(updatedAction)
                    selectedAction = updatedAction
                }
            } else {
                VStack {
                    Text("Select an action to edit")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if selectedAction == nil, let first = store.actions.first {
                selectedAction = first
            }
        }
    }

    func addNewAction() {
        let newAction = Action(
            name: "New Action",
            icon: "star",
            prompt: "Enter your prompt here...",
            shortcut: ""
        )
        store.addAction(newAction)
        selectedAction = newAction
    }

    func deleteSelectedAction() {
        if let action = selectedAction {
            store.deleteAction(action)
            selectedAction = store.actions.first
        }
    }
}

// MARK: - Action Editor

struct ActionEditorView: View {
    @State var action: Action
    var onSave: (Action) -> Void

    @State private var isRecordingShortcut = false

    let iconOptions = [
        "pencil", "arrow.triangle.2.circlepath", "arrow.down.left.and.arrow.up.right",
        "doc.text", "globe", "globe.americas", "star", "bolt", "wand.and.stars",
        "text.bubble", "checkmark.circle", "lightbulb", "brain"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with icon and name
                HStack(spacing: 16) {
                    Menu {
                        ForEach(iconOptions, id: \.self) { icon in
                            Button(action: {
                                action.icon = icon
                                onSave(action)
                            }) {
                                Label(icon, systemImage: icon)
                            }
                        }
                    } label: {
                        Image(systemName: action.icon)
                            .font(.system(size: 24))
                            .foregroundColor(.accentColor)
                            .frame(width: 44, height: 44)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .menuStyle(.borderlessButton)

                    TextField("Action Name", text: $action.name)
                        .textFieldStyle(.plain)
                        .font(.title2.bold())
                        .onChange(of: action.name) { _, _ in
                            onSave(action)
                        }
                }

                Divider()

                // Shortcut
                VStack(alignment: .leading, spacing: 8) {
                    Text("Keyboard Shortcut")
                        .font(.headline)

                    HStack {
                        Text("⌘ +")
                            .foregroundColor(.secondary)

                        TextField("Key", text: $action.shortcut)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            .onChange(of: action.shortcut) { _, newValue in
                                action.shortcut = newValue.uppercased().prefix(1).description
                                onSave(action)
                            }

                        Spacer()
                    }
                }

                // Prompt
                VStack(alignment: .leading, spacing: 8) {
                    Text("Prompt")
                        .font(.headline)

                    TextEditor(text: $action.prompt)
                        .font(.body)
                        .frame(minHeight: 150)
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .onChange(of: action.prompt) { _, _ in
                            onSave(action)
                        }

                    Text("This prompt will be sent to the AI along with the selected text.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(24)
        }
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.cursor")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("Typo")
                .font(.largeTitle.bold())

            Text("Version 1.0.0")
                .foregroundColor(.secondary)

            Text("Transform text with AI-powered shortcuts")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Spacer()

            Text("Made with SwiftUI")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    SettingsView()
}
