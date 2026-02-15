# ShortcutAI Windows App - Functional Testing Guide

This document provides a comprehensive checklist for testing all features of the ShortcutAI Windows application before release.

## Prerequisites

- Windows 10 or Windows 11
- Test environment with various applications (Notepad, Word, browser, etc.)
- API keys for at least one AI provider (OpenAI, Anthropic, etc.)

## Testing Checklist

### 1. Installation & First Launch

- [ ] Install the application from the MSI/EXE installer
- [ ] Verify the app appears in Windows Start Menu
- [ ] Verify the app icon displays correctly in Start Menu
- [ ] Launch the application for the first time
- [ ] Confirm setup wizard appears

### 2. Setup Wizard

#### Step 1: Permissions Check
- [ ] Verify "Global Shortcut Ready" shows ✓
- [ ] Verify "Clipboard Ready" shows ✓
- [ ] Click "Next" to proceed

#### Step 2: Provider & API Key Configuration
- [ ] Select each provider from dropdown (OpenAI, Anthropic, OpenRouter, Perplexity, Groq)
- [ ] Enter a valid API key
- [ ] Verify masked API key display (••••••)
- [ ] Click "Next" to proceed

#### Step 3: Actions Configuration
- [ ] Create first action with name and prompt
- [ ] Click "Add New Action" to create second action
- [ ] Verify inline editing of actions works
- [ ] Verify deletion of actions works (but not the last one)
- [ ] Click "Complete Setup"

### 3. System Tray Integration

- [ ] Verify ShortcutAI icon appears in Windows system tray (bottom-right)
- [ ] Left-click tray icon → window shows
- [ ] Right-click tray icon → context menu appears
- [ ] Select "Show ShortcutAI" → window shows
- [ ] Select "Quit" → application exits completely

### 4. Global Shortcut & Text Capture

#### Basic Text Capture
1. [ ] Open Notepad and type some text (e.g., "Hello world this is a test")
2. [ ] Select the text with mouse/keyboard
3. [ ] Press the registered shortcut (default: Ctrl+Shift+T)
4. [ ] Verify:
   - [ ] ShortcutAI window appears immediately
   - [ ] Popup shows the captured text correctly
   - [ ] Original clipboard content is preserved

#### Edge Cases
- [ ] Test with emoji text: "Hello 👋 世界 🌍"
- [ ] Test with multi-line text
- [ ] Test with special characters: `<>&"'`
- [ ] Test with empty selection (should capture empty string)
- [ ] Test in different applications:
  - [ ] Notepad
  - [ ] Microsoft Word
  - [ ] Web browser (Chrome/Edge)
  - [ ] VS Code or other editors

### 5. Action Popup & AI Processing

#### Single Action Flow
1. [ ] Trigger shortcut with selected text
2. [ ] Verify popup displays with:
   - [ ] "CAPTURED TEXT" section showing selected text
   - [ ] List of all available actions
   - [ ] "Run" button for each action
3. [ ] Click "Run" on an action
4. [ ] Verify:
   - [ ] Button shows "Running..." state
   - [ ] Other actions remain clickable
5. [ ] Wait for AI response
6. [ ] Verify:
   - [ ] "RESULT" section appears with AI output
   - [ ] Result text is displayed correctly
   - [ ] "Apply & Paste" and "Copy Result" buttons appear

#### Multiple Actions
- [ ] Test running different actions on the same captured text
- [ ] Verify each action uses its own prompt
- [ ] Verify results are different for different actions

#### Error Handling
- [ ] Test with invalid API key → verify error message appears
- [ ] Test with network disconnected → verify timeout/error message
- [ ] Test with very long input text (>1000 chars) → verify handling

### 6. Result Application

#### Paste-back Flow
1. [ ] Capture text from Notepad
2. [ ] Run an action and get result
3. [ ] Click "Apply & Paste"
4. [ ] Verify:
   - [ ] ShortcutAI window hides
   - [ ] Original Notepad window regains focus
   - [ ] Result is pasted at cursor position
   - [ ] Pasted text matches the result exactly

#### Copy Result
1. [ ] Get a result from an action
2. [ ] Click "Copy Result"
3. [ ] Paste into another application (Ctrl+V)
4. [ ] Verify copied text matches the result

#### Close Popup
- [ ] Click "Close" button → popup closes without pasting
- [ ] Trigger shortcut again → new capture works

### 7. Settings & Configuration

#### Language Switching
- [ ] Switch to System → verify UI updates
- [ ] Switch to English → verify all text is in English
- [ ] Switch to 日本語 → verify all text is in Japanese
- [ ] Restart app → verify language persists

#### Provider Change
- [ ] Change AI provider in Settings
- [ ] Verify new provider is used for next action
- [ ] Test with different providers for same prompt

#### API Key Update
- [ ] Update API key in Settings
- [ ] Test that new key works for AI calls
- [ ] Verify old key is overwritten (not both stored)

#### Actions Management
- [ ] Edit existing action name and prompt
- [ ] Add multiple new actions (test with 5+ actions)
- [ ] Delete an action (verify can't delete last one)
- [ ] Set a different action as default
- [ ] Verify changes persist after app restart

### 8. Secure Storage Verification

#### First-time Setup
- [ ] Complete setup wizard with API key
- [ ] Check `%APPDATA%\ShortcutAI\setup.json`
- [ ] Verify API key is NOT present in the JSON file
- [ ] Verify other settings (provider, actions) are present

#### Legacy Migration
1. [ ] Create a legacy setup.json with plain-text API key:
   ```json
   {
     "provider": "OpenAI",
     "apiKey": "sk-test-key",
     "actions": [...],
     "setupCompletedAt": "2024-01-01T00:00:00Z"
   }
   ```
2. [ ] Launch the app
3. [ ] Verify:
   - [ ] App loads the API key successfully
   - [ ] setup.json is updated with `apiKey` field removed
   - [ ] API key is now in Windows Credential Manager

#### Credential Manager Check
- [ ] Open Windows Credential Manager (Control Panel → Credential Manager)
- [ ] Navigate to "Windows Credentials"
- [ ] Search for "ShortcutAI"
- [ ] Verify entry exists with username "api_key"
- [ ] Verify password is masked

### 9. Execution Logs & Analytics

- [ ] Run several actions with different prompts
- [ ] Navigate to Settings/Logs section
- [ ] Verify:
  - [ ] Each execution is logged with timestamp
  - [ ] Input/output lengths are recorded
  - [ ] Success/failure status is correct
  - [ ] Provider and model info is captured

### 10. Browser Preview Mode

- [ ] Run `npm run dev` (not `npm run tauri:dev`)
- [ ] Open http://127.0.0.1:1420 in browser
- [ ] Verify:
  - [ ] Setup wizard works with localStorage
  - [ ] Settings can be saved and loaded
  - [ ] Note about "Browser preview mode" is shown
  - [ ] Global shortcut features are disabled gracefully

### 11. Performance & Stability

- [ ] Run 10+ consecutive text captures without issues
- [ ] Test rapid shortcut triggers (press Ctrl+Shift+T multiple times quickly)
- [ ] Leave app running in system tray for 1+ hour
- [ ] Test app behavior after Windows sleep/resume
- [ ] Test app behavior with multiple monitors

### 12. Build & Distribution

- [ ] Build succeeds without errors: `npm run tauri:build`
- [ ] Output files exist in `src-tauri/target/release/bundle/`
- [ ] MSI installer size is reasonable (<50 MB)
- [ ] Install from MSI on clean Windows machine
- [ ] Uninstall via Windows Settings → verify clean removal

## Known Limitations

Document any discovered limitations here:

- Clipboard-based text capture may fail in apps with clipboard restrictions
- Paste-back requires original window to accept Ctrl+V simulation
- API keys stored in Windows Credential Manager (not encrypted file)

## Bug Reporting

If you discover issues during testing:

1. Note the specific step that failed
2. Capture screenshots or error messages
3. Check `%APPDATA%\ShortcutAI\` for log files
4. Report to the development team with reproduction steps

## Testing Sign-off

| Test Category | Tester | Date | Status | Notes |
|--------------|--------|------|--------|-------|
| Installation | | | | |
| Setup Wizard | | | | |
| System Tray | | | | |
| Text Capture | | | | |
| AI Processing | | | | |
| Paste-back | | | | |
| Settings | | | | |
| Secure Storage | | | | |
| Logs | | | | |
| Performance | | | | |

## Release Criteria

The Windows app is ready for release when:

- ✅ All icon files are generated
- ✅ Secure API key storage is implemented
- ✅ Build completes successfully
- ✅ All critical test cases pass
- ✅ No blocking bugs remain
- ✅ Documentation is complete

**Optional for v1.0:**
- Auto-start on Windows login
- Per-action custom shortcuts
- Action categories/tags
