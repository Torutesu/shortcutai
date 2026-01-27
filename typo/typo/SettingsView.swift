//
//  SettingsView.swift
//  typo
//

import SwiftUI
import AppKit

// MARK: - Custom Font Extension

extension Font {
    static func nunitoBlack(size: CGFloat) -> Font {
        return .custom("Nunito Black", size: size)
    }

    static func nunitoBold(size: CGFloat) -> Font {
        return .custom("Nunito ExtraBold", size: size)
    }

    static func nunitoRegularBold(size: CGFloat) -> Font {
        return .custom("Nunito Bold", size: size)
    }
}

// MARK: - Helper Function

func openAccessibilitySettings() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
        NSWorkspace.shared.open(url)
    }
}

struct SettingsView: View {
    @StateObject private var store = ActionsStore.shared
    @StateObject private var authManager = AuthManager.shared
    @State private var selectedTab = 1
    @State private var selectedAction: Action?

    // Theme preference (using AppStorage for automatic updates)
    @AppStorage("appTheme") private var appTheme: String = "System"

    // Get saved color scheme for theme
    private var savedColorScheme: ColorScheme? {
        switch appTheme {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil // System follows OS
        }
    }

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                // Show full settings when logged in
                authenticatedView
            } else {
                // Show login view when not logged in
                LoginRequiredView()
            }
        }
        .frame(width: 700, height: 540)
        .preferredColorScheme(savedColorScheme)
    }

    private var authenticatedView: some View {
        VStack(spacing: 0) {
            // Custom Tab Bar - solo textos con Nunito
            HStack(spacing: 24) {
                TabTextButton(title: "General", isSelected: selectedTab == 0) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedTab = 0
                    }
                }
                TabTextButton(title: "Actions", isSelected: selectedTab == 1) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedTab = 1
                    }
                }
                TabTextButton(title: "Templates", isSelected: selectedTab == 2) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedTab = 2
                    }
                }
                TabTextButton(title: "Plugins", isSelected: selectedTab == 3) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedTab = 3
                    }
                }
                TabTextButton(title: "About", isSelected: selectedTab == 4) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedTab = 4
                    }
                }
            }
            .padding(.vertical, 12)

            Divider()

            // Tab Content with animation
            Group {
                switch selectedTab {
                case 0:
                    GeneralSettingsView()
                case 1:
                    ActionsSettingsView(selectedAction: $selectedAction)
                case 2:
                    TemplatesView(onNavigateToActions: { action in
                        selectedAction = action
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedTab = 1
                        }
                    })
                case 3:
                    PluginsMarketplaceView()
                case 4:
                    AboutView()
                default:
                    EmptyView()
                }
            }
            .id(selectedTab)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
        }
    }
}

// MARK: - Custom Tab Text Button

struct TabTextButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.nunitoBold(size: 14))
                .foregroundColor(isSelected ? Color(red: 0.0, green: 0.584, blue: 1.0) : .secondary)
        }
        .buttonStyle(.plain)
    }
}


// MARK: - 3D Keyboard Key

struct Keyboard3DKey: View {
    @Environment(\.colorScheme) var colorScheme
    let text: String

    var body: some View {
        ZStack {
            // Bottom layer (3D effect)
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? Color(white: 0.25) : Color(white: 0.7))
                .frame(width: 36, height: 36)
                .offset(y: 3)

            // Top layer
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? Color.white : Color(white: 0.95))
                .frame(width: 36, height: 36)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(colorScheme == .dark ? 0 : 0.3), lineWidth: 1)
                )

            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)
        }
        .frame(width: 36, height: 39)
    }
}

// MARK: - Settings 3D Key (smaller for settings view)

struct Settings3DKey: View {
    @Environment(\.colorScheme) var colorScheme
    let text: String

    var body: some View {
        ZStack {
            // Bottom layer (3D effect) - more pronounced in dark mode
            RoundedRectangle(cornerRadius: 6)
                .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.7))
                .frame(width: 30, height: 30)
                .offset(y: colorScheme == .dark ? 3 : 2)

            // Top layer
            RoundedRectangle(cornerRadius: 6)
                .fill(colorScheme == .dark ? Color(white: 0.3) : Color(white: 0.95))
                .frame(width: 30, height: 30)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(colorScheme == .dark ? Color(white: 0.4) : Color.gray.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: colorScheme == .dark ? Color.black.opacity(0.3) : Color.clear, radius: 2, x: 0, y: 1)

            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? .white : .black)
        }
        .frame(width: 30, height: colorScheme == .dark ? 33 : 32)
    }
}

// MARK: - 3D Keyboard Key Large (for empty state)

struct Keyboard3DKeyLarge: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Bottom layer (3D effect)
            RoundedRectangle(cornerRadius: 14)
                .fill(colorScheme == .dark ? Color(white: 0.25) : Color(white: 0.7))
                .frame(width: 64, height: 64)
                .offset(y: 4)

            // Top layer
            RoundedRectangle(cornerRadius: 14)
                .fill(colorScheme == .dark ? Color.white : Color(white: 0.95))
                .frame(width: 64, height: 64)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.gray.opacity(colorScheme == .dark ? 0 : 0.3), lineWidth: 1)
                )

            Image(systemName: "command")
                .font(.system(size: 28, weight: .regular))
                .foregroundColor(Color(white: 0.35))
        }
        .frame(width: 64, height: 68)
    }
}

// MARK: - 3D Keyboard Key Editable

struct Keyboard3DKeyEditable: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var text: String
    var onSave: () -> Void

    var body: some View {
        ZStack {
            // Bottom layer (3D effect)
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? Color(white: 0.25) : Color(white: 0.7))
                .frame(width: 44, height: 36)
                .offset(y: 3)

            // Top layer
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? Color.white : Color(white: 0.95))
                .frame(width: 44, height: 36)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(colorScheme == .dark ? 0 : 0.3), lineWidth: 1)
                )

            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .frame(width: 44, height: 36)
                .onChange(of: text) { _, newValue in
                    text = newValue.uppercased().prefix(1).description
                    onSave()
                }
        }
        .frame(width: 44, height: 39)
    }
}

// MARK: - Dot Pattern Background

struct DotPatternView: View {
    let dotSize: CGFloat = 2
    let spacing: CGFloat = 20

    var body: some View {
        GeometryReader { geometry in
            let columns = Int(geometry.size.width / spacing) + 1
            let rows = Int(geometry.size.height / spacing) + 1

            Canvas { context, size in
                for row in 0..<rows {
                    for col in 0..<columns {
                        let x = CGFloat(col) * spacing
                        let y = CGFloat(row) * spacing
                        let rect = CGRect(x: x - dotSize/2, y: y - dotSize/2, width: dotSize, height: dotSize)
                        context.fill(Circle().path(in: rect), with: .color(Color.gray.opacity(0.15)))
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
