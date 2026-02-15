# ShortcutAI Roadmap

## Current Status

- Desktop support: macOS + Windows preview scaffold
- Core experience: global shortcut, selected text capture, AI actions, plugins

## Near-Term Priorities

1. Language UX
   - Add explicit in-app language switching (`System / English / 日本語`)
   - Expand translated strings in all major flows
2. Onboarding
   - One-screen setup flow: permission check, API setup, first action creation
3. Prompt quality loop
   - Local execution logs (success rate, failure reasons, latency)
   - Automatic prompt improvement suggestions from usage data

## Windows Plan

1. Platform-independent core
   - Extract AI action execution, prompt recommendation, and log processing into a shared core layer
2. Windows client
   - Implement Windows desktop client (recommended stack: Tauri + React or .NET MAUI)
3. OS integrations
   - Global hotkey registration
   - Reliable selected text capture
   - Safe foreground app paste-back flow
4. Parity milestone
   - Match macOS functionality for actions, settings, and onboarding

## Definition of Done (Cross-Platform)

- macOS + Windows both support:
  - Global shortcut launch
  - Action execution against selected text
  - In-app language switch
  - Setup wizard and log-based prompt suggestions
