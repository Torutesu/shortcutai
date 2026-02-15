# ShortcutAI Windows App (Preview)

## Status

This app is an implementation scaffold for Windows using Tauri + React.

Implemented now:

- In-app language switch (`System / English / 日本語`)
- One-screen setup wizard (permission check, API key, first action)
- Local execution logs + prompt auto-suggestion
- Native persistence commands via Tauri (`setup.json`, `execution-logs.json`)

## Prerequisites (Windows)

- Node.js 20+
- Rust stable (with `rustup`)
- Visual Studio Build Tools (C++ workload)
- WebView2 Runtime

## Run in browser preview

```bash
cd apps/windows
npm install
npm run dev
```

## Run as Tauri desktop app

```bash
cd apps/windows
npm install
npm run tauri:dev
```

## Build desktop package

```bash
cd apps/windows
npm run tauri:build
```

## Next implementation targets

1. Real global shortcut registration on Windows.
2. Selected text capture + safe paste-back flow.
3. Provider SDK integration and secure API key storage.
