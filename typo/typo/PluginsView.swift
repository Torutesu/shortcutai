//
//  PluginsView.swift
//  typo
//
//  Plugins marketplace view for browsing and installing plugins
//

import SwiftUI

// MARK: - Plugins Marketplace View

struct PluginsMarketplaceView: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var store = ActionsStore.shared
    @State private var selectedPlugin: PluginType? = nil

    // Adaptive gray: darker in light mode, lighter in dark mode
    var textGrayColor: Color {
        colorScheme == .light
            ? Color(white: 0.35)
            : Color(white: 0.65)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar - Plugins list
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(PluginType.allCases, id: \.self) { plugin in
                            PluginListRow(
                                plugin: plugin,
                                isSelected: selectedPlugin == plugin,
                                isInstalled: store.isPluginInstalled(plugin)
                            )
                            .onTapGesture {
                                selectedPlugin = plugin
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                }
                .scrollIndicators(.hidden)

                // Coming soon text
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .medium))
                    Text("More coming soon...")
                        .font(.nunitoRegularBold(size: 13))
                }
                .foregroundColor(Color(red: 0.0, green: 0.584, blue: 1.0))
                .padding(.vertical, 12)
                .padding(.horizontal, 18)
            }
            .frame(width: 220)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            Divider()

            // Plugin Detail or Empty State
            if let plugin = selectedPlugin {
                PluginDetailView(
                    plugin: plugin,
                    isInstalled: store.isPluginInstalled(plugin),
                    onToggle: {
                        if store.isPluginInstalled(plugin) {
                            store.uninstallPlugin(plugin)
                        } else {
                            store.installPlugin(plugin)
                        }
                    }
                )
            } else {
                // Empty state with dot pattern background
                ZStack {
                    DotPatternView()

                    VStack(spacing: 24) {
                        // Plugin icon - 3D style
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

                            Image(systemName: "puzzlepiece.extension")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(.black)
                        }
                        .frame(width: 64, height: 68)

                        VStack(spacing: 10) {
                            Text("No Plugin Selected")
                                .font(.nunitoBold(size: 20))
                                .foregroundColor(.primary)

                            Text("Select a plugin from the list to see\ndetails and install it.")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
    }
}

// MARK: - Plugin List Row

struct PluginListRow: View {
    @Environment(\.colorScheme) var colorScheme
    let plugin: PluginType
    let isSelected: Bool
    let isInstalled: Bool

    // Selected background color
    var selectedBackgroundColor: Color {
        if !isSelected {
            return Color.clear
        }
        return colorScheme == .light
            ? Color(red: 241/255, green: 241/255, blue: 239/255)
            : Color.accentColor.opacity(0.1)
    }

    // Adaptive gray
    var textGrayColor: Color {
        colorScheme == .light
            ? Color(white: 0.35)
            : Color(white: 0.65)
    }

    var body: some View {
        HStack(spacing: 10) {
            // Icon
            Image(systemName: plugin.icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(textGrayColor)
                .frame(width: 24)

            // Name
            Text(plugin.displayName)
                .font(.nunitoRegularBold(size: 14))
                .foregroundColor(textGrayColor)
                .lineLimit(1)

            Spacer()

            // Installed indicator
            if isInstalled {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(selectedBackgroundColor)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Plugin Detail View

struct PluginDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    let plugin: PluginType
    let isInstalled: Bool
    let onToggle: () -> Void

    var inputBackgroundColor: Color {
        colorScheme == .light
            ? Color(red: 241/255, green: 241/255, blue: 239/255)
            : Color(NSColor.controlBackgroundColor)
    }

    var textGrayColor: Color {
        colorScheme == .light
            ? Color(white: 0.35)
            : Color(white: 0.65)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with icon and name
                    HStack(spacing: 12) {
                        // Icon
                        Image(systemName: plugin.icon)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(textGrayColor)
                            .frame(width: 36, height: 36)

                        Text(plugin.displayName)
                            .font(.nunitoBold(size: 22))
                            .foregroundColor(textGrayColor)

                        Spacer()
                    }

                    // Category badge
                    HStack {
                        Image(systemName: "folder")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.0, green: 0.584, blue: 1.0))
                        Text(plugin.category.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(red: 0.0, green: 0.584, blue: 1.0))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.0, green: 0.584, blue: 1.0).opacity(0.1))
                    .clipShape(Capsule())

                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.nunitoRegularBold(size: 14))
                            .foregroundColor(textGrayColor)

                        Text(plugin.description)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(inputBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                    )

                    // Plugin info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Details")
                            .font(.nunitoRegularBold(size: 14))
                            .foregroundColor(textGrayColor)

                        // Input type
                        HStack {
                            Image(systemName: "arrow.right.circle")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            Text("Input:")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            Text(pluginInputDescription)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(textGrayColor)
                        }

                        // Output type
                        HStack {
                            Image(systemName: "arrow.left.circle")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            Text("Output:")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            Text(plugin.outputsImage ? "Image" : "Text")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(textGrayColor)
                            if plugin.outputsImage {
                                Image(systemName: "photo")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(inputBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                    )

                    Spacer()
                }
                .padding(24)
            }

            Divider()

            // Bottom action bar
            HStack {
                if isInstalled {
                    Text("This plugin is installed")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Install/Uninstall button - 3D style like Actions
                Button(action: onToggle) {
                    Text(isInstalled ? "Uninstall" : "Install")
                        .font(.nunitoBold(size: 14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            ZStack {
                                // Bottom layer (3D effect)
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(isInstalled ? Color(red: 0.6, green: 0.2, blue: 0.2) : Color(red: 0.0, green: 0.45, blue: 0.8))
                                    .offset(y: 3)

                                // Top layer
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(isInstalled ? Color.red.opacity(0.8) : Color(red: 0.0, green: 0.584, blue: 1.0))
                            }
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    var pluginInputDescription: String {
        switch plugin {
        case .qrGenerator:
            return "Text or URL"
        case .imageConverter:
            return "Image from clipboard"
        case .colorPicker:
            return "None (picks from screen)"
        }
    }
}

// MARK: - Plugin Info View (for action editor)

struct PluginInfoView: View {
    let pluginType: PluginType
    let inputBackgroundColor: Color
    let textGrayColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Plugin type badge
            HStack {
                Image(systemName: "puzzlepiece.extension.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text("Native Plugin")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.accentColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.1))
            .clipShape(Capsule())

            // Plugin description
            Text(pluginType.description)
                .font(.nunitoRegularBold(size: 14))
                .foregroundColor(textGrayColor)

            // Plugin-specific info
            VStack(alignment: .leading, spacing: 8) {
                pluginSpecificInfo
            }

            // Category
            HStack {
                Text("Category:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text(pluginType.category.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(textGrayColor)
            }

            // Output type
            HStack {
                Text("Output:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text(pluginType.outputsImage ? "Image" : "Text")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(textGrayColor)
                if pluginType.outputsImage {
                    Image(systemName: "photo")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(inputBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
    }

    @ViewBuilder
    var pluginSpecificInfo: some View {
        switch pluginType {
        case .qrGenerator:
            infoRow(icon: "qrcode", title: "Input", description: "Any text or URL to encode")
        case .imageConverter:
            infoRow(icon: "photo.on.rectangle.angled", title: "Input", description: "Copy an image to clipboard, then run this action")
        case .colorPicker:
            infoRow(icon: "eyedropper", title: "Input", description: "No input required - click anywhere on screen to pick a color")
        }
    }

    func infoRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(textGrayColor)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PluginsMarketplaceView()
        .frame(width: 700, height: 520)
}
