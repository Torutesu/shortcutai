# Building the macOS App

This document explains how to build the ShortcutAI macOS application.

## Prerequisites

- macOS 14.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

## Required Configuration

Before building, you **must** create a `typo/Secrets.swift` file with your actual credentials:

```swift
//
//  Secrets.swift
//  typo
//
//  Configuration secrets for ShortcutAI
//

import Foundation

enum Secrets {
    // Supabase Configuration
    // Get these from: https://supabase.com/dashboard/project/_/settings/api
    static let supabaseURL = "https://your-project.supabase.co"
    static let supabaseAnonKey = "your-supabase-anon-key-here"

    // Stripe Configuration
    static let createCheckoutURL = "https://your-api-endpoint.com/create-checkout"
    static let stripePortalURL = "https://your-api-endpoint.com/customer-portal"

    // OAuth Redirect URI
    static let redirectURI = "textab://auth/callback"
}
```

> **Note:** `Secrets.swift` is in `.gitignore` to prevent committing sensitive credentials.

## Build Commands

### Development Build

```bash
cd typo
xcodebuild -scheme typo -configuration Debug build
```

### Release Build (Unsigned)

For local testing without code signing:

```bash
cd typo
xcodebuild -scheme typo -configuration Release build \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

The built app will be at:
```
~/Library/Developer/Xcode/DerivedData/typo-*/Build/Products/Release/typo.app
```

### Release Build (Signed)

For distribution:

```bash
cd typo
xcodebuild -scheme typo -configuration Release build
```

> **Note:** This requires a valid Apple Developer certificate.

## Recent Fixes Applied

- ✅ Added `import Combine` to ExecutionLogStore.swift
- ✅ Created placeholder Secrets.swift file structure
- ✅ Fixed deployment target from 26.0 → 14.0

## Build Output

- **Binary size:** ~14 MB
- **Location:** `typo/typo.app` (copied from DerivedData)
- **Deployment target:** macOS 14.0+
- **Architecture:** arm64 (Apple Silicon)

## Troubleshooting

### "Cannot find 'Secrets' in scope"

Create `typo/Secrets.swift` with the template above.

### "Code signing error"

Use the unsigned build command above for local testing.

### "Deployment target too high/low"

The app requires macOS 14.0 or later due to SwiftUI API usage (`.onKeyPress`).

## Project Structure

- **Frontend:** SwiftUI
- **Auth:** Supabase
- **Payments:** Stripe
- **Features:** Onboarding, Actions, Templates, Plugins, Chat
- **Storage:** macOS Keychain for secure credentials

## See Also

- [ShortcutAI Windows App](../apps/windows/README.md) - Cross-platform alternative using Tauri + React
