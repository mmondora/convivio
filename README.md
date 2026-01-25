# 🍷 Convivio

> Personal wine cellar management app with AI-powered recommendations

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Firebase](https://img.shields.io/badge/Firebase-11.0-yellow.svg)](https://firebase.google.com)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Overview

Convivio è un'app per la gestione della cantina personale con intelligenza artificiale integrata. Risponde a tre domande fondamentali:

1. **Che vino ho?** - Inventario completo con posizione fisica
2. **Quale servo?** - Suggerimenti AI basati su ospiti e menu
3. **Come lo servo?** - Istruzioni su temperatura, decantazione, bicchieri

## Features

### MVP (v1.0)

- 📸 **Scan etichette** - Aggiungi vini fotografando l'etichetta (Vision API + Claude)
- 🗄️ **Gestione cantina** - Organizza per scaffale/riga/slot
- ⭐ **Rating personali** - Vota e annota i tuoi vini
- 👥 **Gestione amici** - Traccia preferenze alimentari e intolleranze
- 🍽️ **Pianificazione cene** - Menu AI con abbinamenti vino
- 💬 **AI Sommelier** - Chat conversazionale con tool calling

### Roadmap

- [ ] Voting remoto ospiti
- [ ] Timeline servizio con notifiche iOS
- [ ] Integrazione dati esterni vini
- [ ] Statistiche e analytics
- [ ] Apple Watch companion

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Client Layer                          │
├─────────────────┬─────────────────┬─────────────────────────┤
│   iOS (SwiftUI) │   Web (Next.js) │   (Future: watchOS)     │
└────────┬────────┴────────┬────────┴─────────────────────────┘
         │                 │
         ▼                 ▼
┌─────────────────────────────────────────────────────────────┐
│                    Firebase Services                         │
├─────────────────┬─────────────────┬─────────────────────────┤
│  Authentication │    Firestore    │       Storage           │
│   (OAuth/Email) │   (NoSQL DB)    │   (Photos/Assets)       │
└────────┬────────┴────────┬────────┴────────┬────────────────┘
         │                 │                 │
         ▼                 ▼                 ▼
┌─────────────────────────────────────────────────────────────┐
│                   Cloud Functions (Gen2)                     │
├─────────────────┬─────────────────┬─────────────────────────┤
│  /api/extract   │  /api/propose   │      /api/chat          │
│  (OCR + LLM)    │  (Menu + Wine)  │   (Conversational)      │
└────────┬────────┴────────┬────────┴────────┬────────────────┘
         │                 │                 │
         ▼                 ▼                 ▼
┌─────────────────────────────────────────────────────────────┐
│                    External Services                         │
├─────────────────┬───────────────────────────────────────────┤
│  Google Vision  │           Anthropic Claude API            │
│     (OCR)       │        (Interpretation + Chat)            │
└─────────────────┴───────────────────────────────────────────┘
```

## Tech Stack

| Layer | Technology |
|-------|------------|
| iOS | SwiftUI, Firebase SDK, Swift Concurrency |
| Web | Next.js 14, React, Tailwind CSS |
| Backend | Cloud Functions Gen2 (TypeScript) |
| Database | Firestore |
| Storage | Firebase Storage |
| Auth | Firebase Auth (Apple, Google, Email) |
| AI/ML | Google Vision API, Claude API |

## Project Structure

```
convivio/
├── firebase/
│   ├── firestore.rules          # Security rules
│   ├── firestore.indexes.json   # Query indexes
│   └── functions/
│       └── src/
│           ├── api/             # HTTP endpoints
│           │   ├── extract.ts   # OCR + LLM pipeline
│           │   ├── propose.ts   # Dinner menu generation
│           │   └── chat.ts      # Conversational AI
│           ├── triggers/        # Firestore triggers
│           └── types/           # Shared TypeScript types
├── ios/
│   └── Convivio/
│       ├── Models/              # Data models
│       ├── Views/               # SwiftUI views
│       ├── Services/            # Business logic
│       └── ConvivioApp.swift    # Entry point
├── web/                         # Next.js app (Phase 2)
└── docs/                        # Documentation
```

## Getting Started

### Prerequisites

- Node.js 20+
- Xcode 15+
- Firebase CLI (`npm install -g firebase-tools`)
- GCP project with billing enabled

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/mmondora/convivio.git
   cd convivio
   ```

2. **Configure Firebase**
   ```bash
   firebase login
   firebase use --add  # Select your project
   ```

3. **Set up environment variables**
   ```bash
   cd firebase/functions
   cp .env.example .env
   # Edit .env with your API keys
   ```

4. **Install dependencies**
   ```bash
   cd firebase/functions
   npm install
   ```

5. **Deploy Firebase resources**
   ```bash
   firebase deploy
   ```

6. **iOS Setup**
   - Open `ios/Convivio.xcodeproj` in Xcode
   - Download `GoogleService-Info.plist` from Firebase Console
   - Add to Xcode project
   - Build and run

### Environment Variables

Create `firebase/functions/.env`:

```env
ANTHROPIC_API_KEY=sk-ant-...
```

## Data Model

### Core Entities

| Entity | Description |
|--------|-------------|
| `Wine` | Master wine record (name, producer, vintage, type) |
| `Bottle` | Physical bottle instance with location |
| `Location` | Hierarchical position (cellar > shelf > slot) |
| `Rating` | User's 1-5 star rating |
| `TasteProfile` | Sensory evaluation (acidity, tannin, body, etc.) |
| `Friend` | Contact with food preferences |
| `DinnerEvent` | Planned dinner with guests and proposals |

### Key Relationships

```
User ──owns──> Cellar ──contains──> Location ──stores──> Bottle
                                                            │
Wine <────────────────────────────────────────────references─┘
  │
  └──rated by──> Rating
  └──profiled──> TasteProfile
```

## API Reference

### POST /api/extract

Extract wine data from label photo.

```typescript
// Request
{
  photoUrl: string,  // Firebase Storage URL
  userId: string
}

// Response
{
  success: boolean,
  extraction: {
    extractedFields: {
      name: { value: string, confidence: number },
      producer: { value: string, confidence: number },
      // ...
    },
    overallConfidence: number
  },
  suggestedMatches: Wine[]  // Similar wines in cellar
}
```

### POST /api/propose

Generate dinner menu with wine pairings.

```typescript
// Request
{
  dinnerId: string,
  userId: string
}

// Response
{
  success: boolean,
  menu: {
    courses: MenuCourse[],
    reasoning: string,
    totalPrepTime: number
  },
  wineProposals: {
    available: WineProposal[],   // From cellar
    suggested: WineProposal[]   // To purchase
  }
}
```

### POST /api/chat

Conversational AI sommelier with tool calling.

```typescript
// Request
{
  message: string,
  conversationId?: string,
  userId: string
}

// Response
{
  success: boolean,
  response: string,
  conversationId: string,
  wineReferences: Wine[]
}
```

## Security

- **Firestore Rules**: Row-level security based on cellar membership
- **Authentication**: Firebase Auth with OAuth providers
- **API Keys**: Stored in Secret Manager, injected at runtime
- **Data Isolation**: Users can only access their own data and shared cellars

## Cost Estimation

| Service | Free Tier | Estimated MVP Cost |
|---------|-----------|-------------------|
| Firebase Auth | 50k MAU | €0 |
| Firestore | 1GB, 50k reads/day | €0 |
| Cloud Functions | 2M invocations/month | €0 |
| Vision API | 1000 units/month | €0 |
| Claude API | Pay-per-use | ~€3-5/month |
| **Total** | | **~€5/month** |

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Anthropic Claude](https://www.anthropic.com/) for AI capabilities
- [Firebase](https://firebase.google.com/) for backend infrastructure
- [Google Vision API](https://cloud.google.com/vision) for OCR
