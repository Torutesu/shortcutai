<p align="center">
  <img src="screenshots/logo.png" width="80" alt="ShortcutAI logo">
</p>

<h1 align="center">ShortcutAI</h1>

<p align="center">Turn any AI task into a keyboard shortcut.</p>

<p align="center">
  <a href="https://textab.me">Website</a> · <a href="https://github.com/Torutesu/shortcutai/issues">Issues</a> · <a href="https://x.com/elmoidev">Twitter</a>
</p>

<br />

<p align="center">
  <img src="screenshots/screenshot1.png" width="100%" alt="Turn any AI task into a Keyboard Shortcut">
</p>

<br />

## About

ShortcutAI is a macOS menu bar app that lets you trigger AI-powered text actions with a keyboard shortcut. Select text in any app, press `Cmd+Shift+T`, pick an action — done.

Your API key, your model. No subscriptions, no middlemen.

<br />

<p align="center">
  <img src="screenshots/screenshot2.png" width="100%" alt="Your AI, your rules">
</p>

<br />

## Features

- **Custom actions** — create unlimited prompts, each with its own shortcut
- **Multiple providers** — OpenAI, Claude, Groq, OpenRouter, Perplexity
- **Plugins** — Chat, QR Generator, Image Converter, Color Picker
- **Privacy first** — your API key talks directly to the provider
- **Works everywhere** — any app, any text field

<br />

<p align="center">
  <img src="screenshots/screenshot3.png" width="100%" alt="Open Source">
</p>

<br />

## Getting started

```bash
git clone https://github.com/Torutesu/shortcutai.git
```

1. Open `typo/typo.xcodeproj` in Xcode
2. Copy the secrets template:
   ```bash
   cp Secrets.example.swift typo/typo/Secrets.swift
   ```
3. Fill in your values in `Secrets.swift` (gitignored)
4. Add `Secrets.swift` to the Xcode target
5. Build and run (`Cmd+R`)

### Requirements

- macOS 13+
- Xcode 15+
- An AI provider API key (OpenAI, Anthropic, etc.)

<br />

## Contributing

Fork it, improve it, make it yours. PRs welcome.

## License

GPL v3 — see [LICENSE](LICENSE).
