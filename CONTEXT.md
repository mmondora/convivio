# CONTEXT.md — Convivio Project Handoff

> Questo file contiene tutto il contesto necessario per continuare lo sviluppo del progetto Convivio. Generato da una sessione claude.ai il 25 gennaio 2026.

---

## 🎯 Project Vision

**Convivio** è un'app personale per la gestione della cantina vini con AI integrata. Risponde a tre domande:

1. **Che vino ho?** → Inventario con posizione fisica (scaffale/riga/slot)
2. **Quale servo?** → Suggerimenti AI basati su ospiti, menu, preferenze
3. **Come lo servo?** → Istruzioni temperatura, decantazione, bicchieri

**Target user**: Wine enthusiast che organizza cene, gestisce 50-500 bottiglie, vuole tenere traccia di rating personali e preferenze alimentari degli ospiti.

**Anti-pattern**: NON è un clone di Vivino, NON è un social network del vino, NON è un database enciclopedico.

---

## 🏗️ Architecture Decisions (ADR Summary)

### ADR-001: Wine vs Bottle Separation
- **Decision**: `Wine` è il master record (nome, produttore, annata), `Bottle` è l'istanza fisica con location
- **Rationale**: Permette tracking posizione, movimenti, multiple bottiglie stesso vino
- **Status**: Implemented

### ADR-002: No Vivino API
- **Decision**: Nessuna integrazione automatica con database esterni vini
- **Rationale**: Vivino non ha API pubblica, altri servizi sono a pagamento o inaffidabili
- **Status**: MVP senza, valutare in v2

### ADR-003: Fuzzy Matching Manuale
- **Decision**: LLM suggerisce match durante inserimento, utente conferma manualmente
- **Rationale**: Deduplicazione automatica troppo rischiosa per data quality
- **Status**: Implemented in extract.ts

### ADR-004: Guest Access Deferred
- **Decision**: In MVP gli ospiti non hanno accesso all'app, host inserisce preferenze manualmente
- **Rationale**: Complessità auth per voting remoto non giustificata in MVP
- **Status**: Deferred to v2

### ADR-005: GCP Free Tier First
- **Decision**: Stack interamente su Firebase/GCP free tier
- **Rationale**: Costo MVP stimato ~€5/mese (principalmente Claude API)
- **Status**: Implemented

### ADR-006: Claude over OpenAI
- **Decision**: Anthropic Claude API per tutte le funzioni AI
- **Rationale**: Migliore reasoning, tool calling più affidabile, preferenza personale
- **Status**: Implemented (claude-sonnet-4-20250514)

---

## 📁 Project Structure

```
convivio/
├── firebase/
│   ├── firebase.json           # Firebase config
│   ├── firestore.rules         # Security rules (RBAC owner/family)
│   ├── firestore.indexes.json  # Query indexes
│   ├── storage.rules           # Storage security
│   └── functions/
│       ├── package.json
│       ├── tsconfig.json
│       ├── .env.example
│       └── src/
│           ├── index.ts        # Entry point, exports
│           ├── types/
│           │   └── index.ts    # Complete TypeScript types
│           ├── api/
│           │   ├── health.ts   # Health check endpoint
│           │   ├── extract.ts  # OCR + LLM wine extraction
│           │   ├── propose.ts  # Dinner menu + wine pairing
│           │   └── chat.ts     # Conversational sommelier
│           └── triggers/
│               └── users.ts    # onCreate/onDelete triggers
├── ios/
│   └── Convivio/
│       ├── ConvivioApp.swift   # Entry point, tab navigation
│       ├── Models/
│       │   └── Models.swift    # Data models (mirror Firestore)
│       ├── Services/
│       │   ├── AuthManager.swift    # Firebase Auth wrapper
│       │   └── FirebaseService.swift # Firestore & Functions API
│       └── Views/
│           ├── AuthenticationView.swift
│           ├── CellarView.swift      # Main inventory
│           ├── ScanView.swift        # Camera + OCR
│           ├── DinnerListView.swift  # Dinner planning
│           ├── ChatView.swift        # AI sommelier
│           └── ProfileView.swift     # Settings, friends
├── web/                        # [NOT STARTED] Next.js app
├── docs/                       # [NOT STARTED] Documentation
├── README.md
├── LICENSE                     # MIT
├── .gitignore
├── setup.sh                    # Project setup script
├── git-setup.sh                # Git init + GitHub push
└── CONTEXT.md                  # This file
```

---

## 🔧 Tech Stack

| Layer | Technology | Notes |
|-------|------------|-------|
| **iOS** | SwiftUI, Swift Concurrency | Target iOS 17+ |
| **Backend** | Cloud Functions Gen2 | TypeScript, Node 20 |
| **Database** | Firestore | NoSQL, real-time sync |
| **Storage** | Firebase Storage | Wine label photos |
| **Auth** | Firebase Auth | Apple, Google, Email |
| **OCR** | Google Vision API | Label text extraction |
| **AI** | Claude API | Interpretation, chat, proposals |
| **Web** | Next.js 14 | [Not started] |

---

## 📊 Data Model (Key Entities)

### Core
- `Wine` — Master: name, producer, vintage, type, region, grapes
- `Bottle` — Instance: wineId, locationId, status, acquiredAt, price
- `Location` — Hierarchy: cellarId > shelf > row > slot
- `Cellar` — Container: name, members (userId → role)
- `Movement` — Audit: bottleId, type (in/out/move), timestamp

### User Data
- `Rating` — 1-5 stars + isFavorite + notes
- `TasteProfile` — Sensory: acidity, tannin, body, sweetness, effervescence
- `Friend` — Contact with foodieLevel
- `FoodPreference` — Type (allergy/intolerance/dislike/diet) + category

### Dinner Planning
- `DinnerEvent` — Date, style, cookingTime, budget, status
- `DinnerGuest` — Link to Friend
- `WineProposal` — Type (available/suggested), wineId, course, reasoning
- `MenuProposal` — Generated menu with courses

### AI/Processing
- `PhotoAsset` — Storage URL, type, linked wine
- `ExtractionResult` — OCR text, extracted fields with confidence
- `Conversation` — Chat session
- `ChatMessage` — Role, content, tool calls/results

---

## 🚀 Current Implementation Status

### ✅ Completed (Phase 1: Foundation)

| Component | Status | Notes |
|-----------|--------|-------|
| Firestore rules | ✅ Done | RBAC owner/family, full validation |
| Firestore indexes | ✅ Done | Optimized for common queries |
| Storage rules | ✅ Done | User-scoped photos |
| TypeScript types | ✅ Done | Complete, shared |
| User triggers | ✅ Done | onCreate (default cellar), onDelete (cascade) |
| Health endpoint | ✅ Done | /api/health |

### ✅ Completed (Phase 2: Intelligence)

| Component | Status | Notes |
|-----------|--------|-------|
| /api/extract | ✅ Done | Vision OCR → Claude interpretation → fuzzy match |
| /api/propose | ✅ Done | Load context → Claude menu + wine pairing |
| /api/chat | ✅ Done | Tool calling: search, details, location, stats, preferences |

### ✅ Completed (iOS App Structure)

| View | Status | Notes |
|------|--------|-------|
| ConvivioApp | ✅ Done | Entry, tabs, auth state |
| AuthManager | ✅ Done | Firebase Auth, Apple Sign In |
| FirebaseService | ✅ Done | Centralized Firestore & Functions API |
| Models | ✅ Done | All entities, Codable |
| AuthenticationView | ✅ Done | Apple, Email login/signup |
| CellarView | ✅ Done | List, filter, search, swipe-to-consume |
| ScanView | ✅ Done | Camera, photo picker, confirmation UI |
| ChatView | ✅ Done | Messages, quick suggestions, typing indicator |
| DinnerListView | ✅ Done | List, new dinner, detail with proposal |
| ProfileView | ✅ Done | Stats, friends, settings, GDPR |

### ⏳ Pending / TODO

| Item | Priority | Notes |
|------|----------|-------|
| GoogleService-Info.plist | P0 | Download from Firebase Console |
| Firebase project setup | P0 | Create project, enable services |
| Location picker in ScanView | P1 | After wine confirmation, select shelf/slot |
| Rating flow after consume | P1 | Prompt to rate after marking consumed |
| Web app (Next.js) | P2 | Management interface, not MVP-critical |
| Push notifications | P2 | Deferred from MVP |
| Statistics view | P2 | Nice-to-have |

---

## 🔌 API Contracts

### POST /api/extract
```typescript
// Request
{ photoUrl: string, userId: string }

// Response
{
  success: boolean,
  extraction: {
    id: string,
    extractedFields: {
      name?: { value: string, confidence: number },
      producer?: { value: string, confidence: number },
      vintage?: { value: string, confidence: number },
      type?: { value: WineType, confidence: number },
      region?: { value: string, confidence: number },
      country?: { value: string, confidence: number },
      alcoholContent?: { value: string, confidence: number },
      grapes?: { value: string, confidence: number }
    },
    overallConfidence: number
  },
  suggestedMatches: Wine[] // Similar wines in user's cellar
}
```

### POST /api/propose
```typescript
// Request
{ dinnerId: string, userId: string }

// Response
{
  success: boolean,
  menu: {
    courses: MenuCourse[],
    reasoning: string,
    seasonContext: string,
    guestConsiderations: string[],
    totalPrepTime: number
  },
  wineProposals: {
    available: WineProposal[],  // From cellar
    suggested: WineProposal[]   // To purchase
  }
}
```

### POST /api/chat
```typescript
// Request
{ message: string, conversationId?: string, userId: string, context?: { cellarId?, dinnerId? } }

// Response
{
  success: boolean,
  response: string,
  conversationId: string,
  wineReferences: Wine[]
}

// Available tools for Claude:
// - search_wines(type?, region?, minRating?, query?, limit?)
// - get_wine_details(wineId | wineName)
// - get_bottle_location(wineId | wineName)
// - get_cellar_stats()
// - get_friend_preferences(friendName)
```

---

## 🎨 UX Patterns & Conventions

### iOS
- **Navigation**: Tab bar (Cantina, Scan, Cena, AI, Profilo)
- **Lists**: Grouped by type, swipe actions for quick operations
- **Sheets**: Modal for create/edit, dismiss via button or swipe
- **Colors**: Wine type colors defined in Models.swift (WineRed, WineWhite, etc.)
- **Loading**: ProgressView with descriptive text
- **Empty states**: ContentUnavailableView with action button

### Code Style
- **Swift**: SwiftUI, async/await, @MainActor for ViewModels
- **TypeScript**: Strict mode, Zod validation, explicit types
- **Naming**: Italian for user-facing strings, English for code

---

## ⚠️ Known Issues & Gotchas

1. **Firebase Functions secrets**: ANTHROPIC_API_KEY must be set via `firebase functions:secrets:set` for production.

2. **Firestore indexes**: Some compound queries may need additional indexes not yet defined. Deploy will fail with clear error message → add index.

3. **Vision API quota**: Free tier = 1000 units/month. For heavy testing, may need billing.

---

## 🚦 Next Steps (Recommended Order)

### Immediate (to get running)
1. Create Firebase project on console.firebase.google.com
2. Enable: Auth, Firestore, Storage, Functions
3. Enable Vision API in GCP Console
4. `cd firebase/functions && npm install`
5. `firebase functions:secrets:set ANTHROPIC_API_KEY`
6. `cd firebase && firebase deploy`
7. Download GoogleService-Info.plist, add to Xcode project
8. Build and run on simulator

### Then (polish)
1. Add location picker after scan confirmation
2. Add rating prompt after consume
3. Test full flow: scan → save → find → consume → rate

### Later (extend)
1. Web app for desktop management
2. Statistics and analytics
3. Export/import functionality
4. Widget for iOS home screen

---

## 💬 Session Notes

Questa sessione ha prodotto:
- PRD completo con mockup UX
- Schema dati Firestore con relationships
- Security rules production-ready
- 4 Cloud Functions complete
- App iOS funzionale con Firebase integration
- Backlog stimato ~55 giorni di lavoro part-time

Il progetto è strutturato per essere esteso. Le convenzioni sono coerenti. Il data model supporta features future (multi-cellar, family sharing, detailed movements).

---

## 📎 Useful Commands

```bash
# Firebase
cd firebase
firebase login
firebase use --add
firebase deploy
firebase emulators:start

# Functions dev
cd firebase/functions
npm run build
npm run serve  # local with emulators

# iOS
open ios/Convivio.xcodeproj
```

---

## 🤖 For Claude Code

Quando lavori su questo progetto:

1. **Leggi prima**: README.md per overview, questo file per contesto dettagliato
2. **Codice esistente**: È tutto funzionante e coerente, estendi non riscrivere
3. **Convenzioni**: Segui i pattern già presenti (ViewModels, Zod validation, etc.)
4. **Lingua**: Codice in inglese, UI strings in italiano
5. **Commit style**: Emoji prefix (🍷 feature, 🐛 fix, 📝 docs, ♻️ refactor)

Se devi fare scelte architetturali significative, documentale come ADR in questo file.

---

*Last updated: 2026-01-25 | Session: claude.ai web + Claude Code*
