# Convivio - Personal Wine Sommelier

iOS app for personal wine cellar management with integrated AI sommelier.

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![SwiftData](https://img.shields.io/badge/SwiftData-iOS%2017+-blue.svg)](https://developer.apple.com/documentation/swiftdata)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Overview

Convivio answers three fundamental questions:

1. **What wine do I have?** - Complete inventory with physical location
2. **Which should I serve?** - AI suggestions based on guests and menu
3. **How do I serve it?** - Optimal pairings for each course

## Architecture

```
┌─────────────────────────────────────────────────┐
│          iOS App (SwiftUI + SwiftData)          │
│    (5 tabs: Cellar, Scan, Dinner, AI, Profile)  │
└───────────────────┬─────────────────────────────┘
                    │
        ┌───────────┼───────────┐
        │           │           │
   ┌────▼────┐ ┌────▼────┐ ┌────▼────┐
   │SwiftData│ │ OpenAI  │ │CloudKit │
   │ (Local) │ │   API   │ │ (Sync)  │
   └─────────┘ └─────────┘ └─────────┘
```

## Tech Stack

| Layer | Technology |
|-------|------------|
| iOS | SwiftUI, Swift Concurrency, iOS 17+ |
| Database | SwiftData (local persistence) |
| Sync | CloudKit (multi-device sync) |
| AI | OpenAI API (GPT-4o) |
| Localization | 4 languages (IT, EN, DE, FR) |

## Project Structure

```
personal_sommelier/
├── ios/                          # iOS App
│   └── Convivio/
│       ├── ConvivioApp.swift     # Entry point + tab navigation
│       ├── Views/
│       │   ├── CellarView.swift       # Wine inventory
│       │   ├── ScanView.swift         # Label scanning
│       │   ├── FoodView.swift         # Dinner planning
│       │   ├── ChatView.swift         # AI Sommelier
│       │   └── ProfileView.swift      # Settings & profile
│       ├── Models/
│       │   ├── Models.swift           # Core data models (SwiftData)
│       │   ├── MenuModels.swift       # Menu generation models
│       │   └── ...                    # Additional models
│       └── Services/
│           ├── OpenAIService.swift    # Direct OpenAI API integration
│           ├── CloudKitService.swift  # Multi-device sync
│           ├── LanguageManager.swift  # Localization system
│           ├── MenuGeneratorService.swift
│           └── ...                    # Additional services
│
├── README.md                     # This file
├── CONTEXT.md                    # Project context & decisions
└── CLAUDE.md                     # Instructions for Claude Code
```

## Data Models

### Wine (Master record)
```swift
@Model
class Wine {
    var name: String
    var producer: String?
    var vintage: Int?
    var type: WineType          // red, white, rosé, sparkling, dessert, fortified
    var region: String?
    var country: String?
    var grapes: [String]?
    var alcohol: Double?
}
```

### Bottle (Physical instance)
```swift
@Model
class Bottle {
    var wine: Wine
    var cellarId: UUID
    var locationId: UUID?
    var status: BottleStatus    // available, reserved, consumed, gifted
    var acquiredAt: Date?
    var acquiredPrice: Double?
    var consumedAt: Date?
}
```

### DinnerEvent (Planned dinner)
```swift
@Model
class DinnerEvent {
    var name: String
    var date: Date
    var guestCount: Int
    var style: DinnerStyle
    var cuisineStyle: String?
    var notes: String?          // User requests (highest priority for AI)
    var status: DinnerStatus
    var menuResponse: MenuResponse?
}
```

## Key Features

### 1. Cellar Management
- Wine inventory with filters and sorting
- Search by name, producer, region
- Physical location tracking (shelf/row/slot)
- Bottle status management (available, reserved, consumed)
- Quick and detailed wine ratings (AIS-style tasting notes)

### 2. Label Scanning
- Capture photos from camera or photo library
- AI-powered wine data extraction via OpenAI Vision
- Fuzzy matching with existing wines
- Confidence score for each field

### 3. Dinner Planning

**Behavior:**
- Create event with parameters (name, date, style, cuisine, budget)
- `notes` field for specific user requests
- **Automatic menu generation** on save
- AI generates 4 courses with wine pairings

**AI Requirements for menu generation:**

1. **User requests have HIGHEST PRIORITY**
   - The `notes` field is passed to AI as "USER SPECIFIC REQUESTS"
   - Examples: "Japanese cuisine", "Seafood menu", "Autumn theme with mushrooms"

2. **4 standard courses**: appetizer, first, main, dessert

3. **Each course has TWO wine pairings:**
   - `cellarWine`: wine from user's cellar (mandatory if available)
   - `marketWine`: wine to purchase as alternative

4. **Minimize wine changes:**
   - Same wine can cover multiple courses
   - Strategy explained in `wineStrategy` field
   - Goal: 2-3 wines maximum per dinner

### 4. AI Sommelier (Chat)
- Conversational chat with AI
- Context-aware responses based on user's cellar
- Wine recommendations for any occasion
- Responds in the user's chosen language
- Quick suggestion chips for common queries

### 5. Localization
- Full UI localization in 4 languages:
  - Italian (default)
  - English
  - German
  - French
- AI Sommelier responds in user's chosen language
- Language can be changed from Settings

### 6. Multi-device Sync
- CloudKit integration for data sync
- Collaborative cellars (family sharing)
- Works across iPhone and iPad

## Development

### Prerequisites
- macOS with Xcode 15+
- iOS 17+ target device or simulator
- OpenAI API key

### Setup

```bash
# Clone
git clone <repo>
cd personal_sommelier

# Open in Xcode
open ios/Convivio.xcodeproj

# Configure API key in AppSettings or environment
# Run on simulator: Cmd+R
```

### Configuration

The app stores the OpenAI API key in `AppSettings` (SwiftData model). Configure it in:
- Settings tab > API Configuration

Or set as environment variable for development.

## Version History

| Version | Date | Description |
|---------|------|-------------|
| v1.6.2 | Jan 2026 | Full localization (4 languages), AI responds in user's language |
| v1.6.1 | Jan 2026 | Cleaner UI, fixed kitchen notes |
| v1.6.0 | Jan 2026 | Separate notes (kitchen/wine/hospitality), temperature notifications |
| v1.5.0 | 2026 | Cellar management, AI Sommelier, menu generation, wine ratings |
| v1.0.0 | 2026 | Initial public release |

## License

MIT

## Author

Mike - mikesoft.it
