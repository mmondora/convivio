# CLAUDE.md — Instructions for Claude Code

## Project Overview

**Convivio** is an iOS app for personal wine cellar management with integrated AI sommelier.

### Tech Stack
- **iOS**: SwiftUI, Swift Concurrency, iOS 17+
- **Database**: SwiftData (local persistence)
- **Sync**: CloudKit (multi-device sync)
- **AI**: OpenAI API (GPT-4o for chat, vision for label scanning)
- **Localization**: 4 languages (IT, EN, DE, FR)

## Project Structure

```
personal_sommelier/
├── ios/Convivio/           # iOS SwiftUI App
│   ├── Views/              # SwiftUI views
│   ├── Models/             # SwiftData models
│   └── Services/           # OpenAIService, CloudKitService, LanguageManager, etc.
├── CONTEXT.md              # Project context & decisions
├── CLAUDE.md               # This file
└── README.md               # Complete documentation
```

## Useful Commands

### iOS
```bash
open ios/Convivio.xcodeproj  # Open in Xcode
# Cmd+R to run on simulator
```

## Code Conventions

### Language
- **Code**: English (variables, functions, technical comments)
- **UI strings**: Localized via L10n enum in LanguageManager.swift

### Swift (iOS)
- SwiftUI with async/await
- @MainActor for ViewModels
- MVVM pattern
- SwiftData for persistence

### Commit Style
Use emoji prefixes:
- 🍷 `feat:` new feature
- 🐛 `fix:` bug fix
- 📝 `docs:` documentation
- ♻️ `refactor:` refactoring
- ✅ `test:` tests

## Main Data Models

- **Wine**: Master wine record (name, producer, vintage, type)
- **Bottle**: Physical bottle with location and status
- **DinnerEvent**: Planned dinner with guests
- **MenuResponse**: Generated menu with wine pairings per course
- **AppSettings**: User settings including language, API key, preferences

## Key Services

| Service | Description |
|---------|-------------|
| `OpenAIService` | Direct OpenAI API calls (chat, vision) |
| `CloudKitService` | Multi-device sync via CloudKit |
| `LanguageManager` | UI localization (4 languages) |
| `MenuGeneratorService` | AI menu generation |
| `LocaleService` | Locale context for AI prompts |

## Important Notes

1. **No Firebase** - The app uses SwiftData for local storage and CloudKit for sync
2. **OpenAI API is called directly** from the iOS app (no backend)
3. **Menu generation is automatic** on dinner save (no "Generate" button)
4. **The dinner `notes` field has HIGHEST PRIORITY** for AI in menu generation
5. **Each course has TWO wine pairings**: one from cellar, one to purchase
6. **AI Sommelier responds in user's chosen language** (configured in Settings)
7. **UI refreshes automatically** when language changes (via .id() modifier)

## Localization System

The app uses a custom localization system in `LanguageManager.swift`:
- `L10n` enum with static computed properties
- `.localized` extension on String
- 4 supported languages: Italian, English, German, French
- Language setting stored in AppSettings (SwiftData)

## Additional Documentation

- `README.md`: Complete overview, data models, features
- `CONTEXT.md`: ADRs, architectural decisions, implementation status
