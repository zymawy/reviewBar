# AGENTS.md - Instructions for AI Coding Assistants

This file provides context and guidelines for AI agents (Claude, Gemini, Copilot, etc.) working on the ReviewBar codebase.

## Project Overview

**ReviewBar** is a macOS menu bar application for AI-powered pull request code reviews. It integrates with GitHub and various LLM providers (API and CLI-based).

## Architecture

```
Sources/
├── ReviewBar/              # Main macOS app (SwiftUI)
│   ├── Views/              # UI components
│   ├── ReviewStore.swift   # Central state management (@Observable)
│   ├── SettingsStore.swift # User preferences (UserDefaults)
│   ├── AppDelegate.swift   # App lifecycle, provider setup
│   └── StatusItemController.swift # Menu bar icon
├── ReviewBarCore/          # Shared library
│   ├── Agents/             # LLM provider implementations
│   ├── Models/             # Data structures (ReviewRequest, ReviewResult)
│   ├── Providers/          # Git provider (GitHub)
│   └── Services/           # PRCloneManager, etc.
└── ReviewBarCLI/           # Command-line interface
```

## Key Patterns

### State Management
- `ReviewStore` is the single source of truth for review state
- Uses `@Published` properties for SwiftUI reactivity
- All async operations use Swift Concurrency (`async/await`)

### LLM Providers
- Protocol: `LLMProvider` in `ReviewBarCore/Agents/`
- API providers: Direct HTTP calls (Claude, OpenAI, Gemini)
- CLI providers: Subprocess execution via `CLILLMProvider`
- CLI tools run in cloned repo directories for full context

### UI Guidelines
- Use SF Symbols for icons (not custom images or emoji)
- Apply `.regularMaterial` for glassmorphism backgrounds
- Cards have hover states with `.scaleEffect` and `.shadow`
- Status updates via `reviewStore.statusMessage`

## Build & Run

```bash
# Development
./Scripts/compile_and_run.sh

# Tests
swift test

# Release build
./Scripts/package_app.sh
```

## Common Tasks

### Adding a new LLM provider
1. Create a new file in `Sources/ReviewBarCore/Agents/`
2. Conform to `LLMProvider` protocol
3. Add case to `LLMProviderType` enum in `SettingsStore.swift`
4. Register in `AppDelegate.createLLMProvider()`

### Adding a new settings option
1. Add key to `Keys` enum in `SettingsStore.swift`
2. Add `@Published` property with `didSet` to save
3. Load in `loadSettings()` method
4. Add UI in `PreferencesView.swift`

### Modifying the menu bar icon
- Edit `StatusItemController.swift`
- Use `NSImage(systemSymbolName:)` for SF Symbols
- Icon is 22x22 with 15pt symbol size

## Code Style

- Follow Swift API Design Guidelines
- Use `// MARK: -` for code sections
- Prefer `let` over `var`
- Run SwiftLint before committing: `swiftlint`
- Run SwiftFormat: `swiftformat .`

## Testing

- Core logic tests in `Tests/ReviewBarCoreTests/`
- Use `XCTest` framework
- Mock external services where possible

## Don't

- ❌ Use `force_try` or `force_cast` in production code
- ❌ Store secrets in code (use Keychain or env vars)
- ❌ Block the main thread with sync operations
- ❌ Use deprecated APIs (target macOS 14+)

## Do

- ✅ Handle errors gracefully with user feedback
- ✅ Use structured logging via `reviewStore.log()`
- ✅ Support both light and dark mode
- ✅ Test on real PRs before committing
