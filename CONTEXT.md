# CONTEXT.md — Convivio Project Handoff

> This file contains all the context needed to continue development on the Convivio project.

---

## Project Vision

**Convivio** is a personal app for wine cellar management with integrated AI. It answers three questions:

1. **What wine do I have?** → Inventory with physical location (shelf/row/slot)
2. **Which should I serve?** → AI suggestions based on guests, menu, preferences
3. **How do I serve it?** → Temperature, decanting, glass instructions

**Target user**: Wine enthusiast who organizes dinners, manages 50-500 bottles, wants to track personal ratings and guest food preferences.

**Anti-pattern**: NOT a Vivino clone, NOT a wine social network, NOT an encyclopedic wine database.

---

## Architecture Decisions (ADR Summary)

### ADR-001: Wine vs Bottle Separation
- **Decision**: `Wine` is the master record (name, producer, vintage), `Bottle` is the physical instance with location
- **Rationale**: Enables position tracking, movements, multiple bottles of same wine
- **Status**: Implemented

### ADR-002: No Vivino API
- **Decision**: No automatic integration with external wine databases
- **Rationale**: Vivino has no public API, other services are paid or unreliable
- **Status**: MVP without, evaluate in v2

### ADR-003: Manual Fuzzy Matching
- **Decision**: AI suggests matches during entry, user confirms manually
- **Rationale**: Automatic deduplication too risky for data quality
- **Status**: Implemented in OpenAIService

### ADR-004: Guest Access Deferred
- **Decision**: In MVP guests don't have app access, host enters preferences manually
- **Rationale**: Auth complexity for remote voting not justified in MVP
- **Status**: Deferred to v2

### ADR-005: Local-First Architecture
- **Decision**: SwiftData for local storage, CloudKit for sync
- **Rationale**: Works offline, fast, no backend costs
- **Status**: Implemented

### ADR-006: OpenAI over Claude
- **Decision**: OpenAI API for all AI functions (was Claude initially)
- **Rationale**: GPT-4o Vision for label scanning, consistent API
- **Status**: Implemented (gpt-4o)

### ADR-007: Direct API Calls
- **Decision**: Call OpenAI API directly from iOS app, no backend
- **Rationale**: Simpler architecture, no server costs, API key stored securely
- **Status**: Implemented

---

## Project Structure

```
personal_sommelier/
├── ios/
│   └── Convivio/
│       ├── ConvivioApp.swift     # Entry point, tab navigation
│       ├── Models/
│       │   ├── Models.swift      # Core SwiftData models
│       │   ├── MenuModels.swift  # Menu generation models
│       │   └── ...               # Additional models
│       ├── Services/
│       │   ├── OpenAIService.swift     # Direct OpenAI API
│       │   ├── CloudKitService.swift   # Multi-device sync
│       │   ├── LanguageManager.swift   # Localization (4 languages)
│       │   ├── MenuGeneratorService.swift
│       │   └── ...                     # Additional services
│       └── Views/
│           ├── CellarView.swift        # Wine inventory
│           ├── ScanView.swift          # Label scanning
│           ├── FoodView.swift          # Dinner planning
│           ├── ChatView.swift          # AI Sommelier
│           └── ProfileView.swift       # Settings
├── README.md
├── CONTEXT.md                  # This file
└── CLAUDE.md                   # Instructions for Claude Code
```

---

## Tech Stack

| Layer | Technology | Notes |
|-------|------------|-------|
| **iOS** | SwiftUI, Swift Concurrency | Target iOS 17+ |
| **Database** | SwiftData | Local persistence |
| **Sync** | CloudKit | Multi-device, family sharing |
| **AI** | OpenAI API (GPT-4o) | Chat, vision, menu generation |
| **Localization** | Custom (LanguageManager) | IT, EN, DE, FR |

---

## Data Model (Key Entities)

### Core
- `Wine` — Master: name, producer, vintage, type, region, grapes
- `Bottle` — Instance: wineId, locationId, status, acquiredAt, price
- `StorageArea` — Location: cellarId, name, position (shelf/row/slot)
- `AppSettings` — User preferences, language, API key

### User Data
- `WineRating` — Stars, tasting notes (AIS-style), isFavorite

### Dinner Planning
- `DinnerEvent` — Date, style, cuisine, budget, status
- `MenuResponse` — Generated menu with courses and wine pairings
- `ConfirmedWine` — Wines selected for the dinner
- `DinnerNotes` — Kitchen, wine, hospitality notes

---

## Current Implementation Status

### Completed

| Component | Status | Notes |
|-----------|--------|-------|
| SwiftData models | Done | Complete, with relationships |
| CloudKit sync | Done | Multi-device, collaborative cellars |
| OpenAI integration | Done | Chat, vision, menu generation |
| CellarView | Done | List, filter, search, ratings |
| ScanView | Done | Camera, photo picker, AI extraction |
| FoodView | Done | Dinners, menu generation, wine confirmation |
| ChatView | Done | AI Sommelier with context |
| ProfileView | Done | Settings, language picker |
| Localization | Done | 4 languages (IT, EN, DE, FR) |
| AI language support | Done | Sommelier responds in user's language |

### Pending / TODO

| Item | Priority | Notes |
|------|----------|-------|
| Detailed menu PDF | P1 | Recipes, shopping list, timeline |
| Debug prompt editor | P2 | For testing AI prompts |
| Wine consumption tracking | P2 | Statistics and history |
| Web app | P3 | Management interface |

---

## UX Patterns & Conventions

### iOS
- **Navigation**: Tab bar (Cellar, Scan, Dinner, AI, Profile)
- **Lists**: Grouped by type, swipe actions for quick operations
- **Sheets**: Modal for create/edit, dismiss via button or swipe
- **Colors**: Wine type colors defined in Models.swift
- **Loading**: ProgressView with descriptive text
- **Empty states**: ContentUnavailableView with action button
- **Language change**: UI refreshes automatically via .id() modifier

### Code Style
- **Swift**: SwiftUI, async/await, @MainActor for ViewModels
- **Naming**: English for code, localized strings via L10n
- **Localization**: All UI strings through L10n enum

---

## Localization System

The app uses a custom localization system:

```swift
// LanguageManager.swift
enum L10n {
    static var cellar: String { "tab.cellar".localized }
    static var scan: String { "tab.scan".localized }
    // ... 100+ localized keys
}

extension String {
    var localized: String {
        LanguageManager.shared.translations[self] ?? self
    }
}
```

Supported languages:
- Italian (default)
- English
- German
- French

---

## Next Steps (Recommended Order)

### Immediate
1. Complete remaining L10n string updates in all views
2. Test all features in each language
3. Implement detailed menu PDF generation

### Then
1. Add debug prompt editor for AI testing
2. Wine consumption statistics
3. Export/import functionality

### Later
1. Web app for desktop management
2. Widget for iOS home screen
3. Apple Watch companion app

---

## For Claude Code

When working on this project:

1. **Read first**: README.md for overview, this file for detailed context
2. **Existing code**: It's all functional and coherent, extend don't rewrite
3. **Conventions**: Follow existing patterns (ViewModels, SwiftData, etc.)
4. **Language**: Code in English, UI strings via L10n localization
5. **Commit style**: Emoji prefix (🍷 feature, 🐛 fix, 📝 docs, ♻️ refactor)

If you need to make significant architectural choices, document them as ADRs in this file.

---

*Last updated: 2026-01-31 | Architecture: SwiftData + CloudKit + OpenAI*
