# App Icons

This directory should contain the application icons for Windows.

## Generate Icons

To generate all required icon formats from a source PNG (1024x1024 recommended):

```bash
npm install -g @tauri-apps/cli
tauri icon path/to/source-icon.png
```

This will generate:
- `icon.ico` - Windows system tray and taskbar icon (32x32, 256x256 variants)
- `icon.png` - Various sizes for different contexts

## Required Icons

For the Windows app to build and run properly, you need at least:
- **icon.ico** - System tray icon (Windows)

## Placeholder

Until icons are generated, the app may fail to build or display a default system icon in the tray.

To create a simple placeholder, use any image editor to create a 512x512 PNG with the ShortcutAI branding, then run the `tauri icon` command above.
