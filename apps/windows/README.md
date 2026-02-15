# ShortcutAI Windows App

Windows desktop implementation of ShortcutAI using Tauri + React.

## Current Status

**Fully implemented:**
- ✅ Global shortcut registration and unregistration
- ✅ Selected text capture via Ctrl+C simulation (clipboard-based)
- ✅ AI provider integration (OpenAI, Anthropic, OpenRouter, Perplexity, Groq)
- ✅ Safe paste-back flow (Ctrl+V simulation to original app)
- ✅ Action popup UI (captured text → run → result → apply)
- ✅ In-app language switch (System / English / 日本語)
- ✅ Setup wizard (permissions, API key, first action)
- ✅ Local execution logs + prompt auto-suggestion via shared core
- ✅ Native persistence (setup.json, execution-logs.json)
- ✅ System tray integration (minimize to tray, left-click to show)
- ✅ Multiple actions support (add, edit, delete actions with full CRUD UI)
- ✅ Action selector in popup (choose which action to run on captured text)
- ✅ Browser preview mode with localStorage fallback
- ✅ **Secure API key storage** (Windows Credential Manager via keyring crate)
- ✅ **Automatic migration** from legacy plain-text API keys to secure storage
- ✅ **App icons** generated for all Windows formats (ICO, PNG)

## Prerequisites

**Windows:**
- Node.js 20+
- Rust stable (via `rustup`: https://rustup.rs/)
- Visual Studio Build Tools with C++ workload
- WebView2 Runtime (usually pre-installed on Windows 10/11)

**Development (any OS):**
- Node.js 20+
- Rust stable (for Tauri backend compilation)

## Run in Browser Preview

```bash
cd apps/windows
npm install
npm run dev
```

Open http://127.0.0.1:1420 in your browser.

**Note:** Browser preview mode simulates the Tauri environment using localStorage and web APIs. Native features (global shortcut, Ctrl+C/V simulation, system tray) won't work.

## Run as Tauri Desktop App

```bash
cd apps/windows
npm install
npm run tauri:dev
```

The app window will appear. The system tray icon will show in the Windows taskbar tray area (bottom-right).

## Build Desktop Package

```bash
cd apps/windows
npm run tauri:build
```

Output: `src-tauri/target/release/bundle/`

**Note:** Windows installers (MSI/EXE) can only be built on Windows hosts. On macOS/Linux, the Rust code will compile successfully, but the final bundle creation will fail. To create distributable Windows packages, run the build on a Windows machine.

## Icon Generation

Icons have been pre-generated from the ShortcutAI logo and are located in `src-tauri/icons/`. This includes:
- `icon.ico` - Windows system tray and taskbar icon
- Various PNG sizes for different contexts
- Store logos for Windows App Store (if needed)

If you need to regenerate icons from a different source image:

```bash
npx @tauri-apps/cli icon path/to/your-icon-1024x1024.png
```

This will replace all icon files in `src-tauri/icons/`.

## How It Works

1. **Setup:** User configures API key, selects provider, defines first action (prompt).
   - API key is stored securely in Windows Credential Manager (not in plain JSON)
   - Legacy plain-text keys are automatically migrated on first load
2. **Global Shortcut:** Registers Ctrl+Shift+T (customizable) via Tauri's GlobalShortcutManager.
3. **Text Capture:** When shortcut fires:
   - Rust backend saves current clipboard
   - Simulates Ctrl+C to copy selected text
   - Reads clipboard, emits `text-captured` event to frontend
   - Restores previous clipboard content
   - Shows app window and focuses it
4. **Action Popup:** Frontend displays captured text, user selects an action and clicks "Run".
5. **AI Call:** Frontend calls AI provider API via fetch() with the selected action's prompt.
6. **Apply & Paste:**
   - User clicks "Apply & Paste"
   - Window hides (original app regains focus)
   - Result is written to clipboard
   - Ctrl+V is simulated to paste into original app
7. **System Tray:** App lives in Windows system tray. Left-click tray icon to show/hide window. Right-click for menu (Show, Quit).

## Future Enhancements

- **Auto-start on login:** Add Windows startup registry entry or Task Scheduler integration
- **Per-action global shortcuts:** Allow assigning different hotkeys to specific actions
- **Action categories/tags:** Organize actions by type (grammar, translation, summarization, etc.)
- **Custom shortcut editor:** UI for changing the global shortcut from default Ctrl+Shift+T

## Architecture

- **Frontend:** React + TypeScript (shared UI logic with macOS where feasible)
- **Backend:** Rust + Tauri v1 (global shortcut, clipboard, keyboard simulation via `arboard` + `enigo`)
- **Secure Storage:** API keys stored in Windows Credential Manager via `keyring` crate
- **Core:** Shared TypeScript library (`shared/core/src`) for action stats, prompt suggestions, execution log schema
- **Platform abstraction:** `platform.ts` provides Tauri vs. browser environment detection and fallbacks

## Secure API Key Storage

API keys are stored securely using Windows Credential Manager:

- **Storage:** API keys are saved via the `keyring` crate to Windows Credential Manager
- **File Storage:** Only provider, actions, and metadata are stored in `%APPDATA%\ShortcutAI\setup.json`
- **Migration:** Existing plain-text API keys are automatically migrated to secure storage on first load
- **Verification:** Check Windows Credential Manager → Windows Credentials → "ShortcutAI" to see stored credentials

This matches the security level of the macOS app, which uses Keychain Services.

## Differences from macOS App

| Feature                     | macOS (Swift)        | Windows (Tauri + React)        |
|-----------------------------|----------------------|--------------------------------|
| Global shortcut             | ✅ NSEvent           | ✅ Tauri GlobalShortcut        |
| Text capture                | ✅ Accessibility API | ✅ Clipboard (Ctrl+C)          |
| Paste-back                  | ✅ CGEvent           | ✅ Clipboard (Ctrl+V)          |
| System tray/menu bar        | ✅ NSStatusBar       | ✅ SystemTray                  |
| Multi-action UI             | ✅                   | ✅ Full CRUD support           |
| Secure keychain storage     | ✅ Keychain Services | ✅ Credential Manager (keyring)|
| AI provider integration     | ✅ Native HTTP       | ✅ Fetch API                   |

## Contributing

See the root [CONTRIBUTING.md](../../CONTRIBUTING.md) for contribution guidelines.
