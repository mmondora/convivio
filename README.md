# Convivio - Personal Wine Sommelier

App iOS per la gestione della cantina personale con AI sommelier integrato.

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Firebase](https://img.shields.io/badge/Firebase-11.0-yellow.svg)](https://firebase.google.com)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Panoramica

Convivio risponde a tre domande fondamentali:

1. **Che vino ho?** - Inventario completo con posizione fisica
2. **Quale servo?** - Suggerimenti AI basati su ospiti e menu
3. **Come lo servo?** - Abbinamenti ottimali per ogni portata

## Architettura

```
┌─────────────────────────────────────────────┐
│        iOS Client (SwiftUI)                 │
│  (5 tabs: Cantina, Scan, Cena, AI, Profilo) │
└────────────────┬────────────────────────────┘
                 │
        ┌────────▼────────┐
        │  Firebase SDK   │
        └────────┬────────┘
                 │
    ┌────────────┼────────────┐
    │            │            │
┌───▼────┐  ┌───▼────┐  ┌────▼───┐
│  Auth  │  │Firestore│  │Storage │
└────────┘  └─────────┘  └────────┘
                 │
    ┌────────────▼────────────┐
    │  Cloud Functions (Gen2) │
    │     europe-west1        │
    ├─────────────────────────┤
    │ extractWineFromPhoto    │
    │ proposeDinnerMenu       │
    │ chatWithSommelier       │
    │ healthCheck             │
    └────────────┬────────────┘
                 │
         ┌───────┼───────┐
         │       │       │
    ┌────▼──┐ ┌──▼───┐ ┌─▼──────┐
    │Google │ │Claude│ │Firebase│
    │Vision │ │ API  │ │ Admin  │
    └───────┘ └──────┘ └────────┘
```

## Stack Tecnologico

| Layer | Tecnologia |
|-------|------------|
| iOS | SwiftUI, Swift Concurrency, iOS 17+ |
| Backend | Cloud Functions Gen2, TypeScript, Node 20 |
| Database | Firestore (NoSQL) |
| Storage | Firebase Storage |
| Auth | Firebase Auth (Apple, Google, Email) |
| OCR | Google Vision API |
| AI | Anthropic Claude API (claude-sonnet-4-20250514) |

## Struttura Progetto

```
personal_sommelier/
├── ios/                          # App iOS
│   └── Convivio/
│       ├── ConvivioApp.swift     # Entry point + Firebase config
│       ├── Views/
│       │   ├── AuthenticationView.swift
│       │   ├── CellarView.swift      # Inventario vini
│       │   ├── ScanView.swift        # Scansione etichette
│       │   ├── DinnerListView.swift  # Pianificazione cene
│       │   ├── ChatView.swift        # AI Sommelier
│       │   └── ProfileView.swift     # Profilo e amici
│       ├── Models/
│       │   └── Models.swift          # Data models
│       └── Services/
│           ├── AuthManager.swift
│           └── FirebaseService.swift
│
├── firebase/                     # Backend Firebase
│   ├── functions/
│   │   └── src/
│   │       ├── index.ts          # Entry point
│   │       ├── api/
│   │       │   ├── extract.ts    # OCR + estrazione vino
│   │       │   ├── propose.ts    # Generazione menu + vini
│   │       │   ├── chat.ts       # Sommelier AI con tool calling
│   │       │   └── health.ts     # Health check
│   │       ├── triggers/
│   │       │   └── users.ts      # onCreate/onDelete user
│   │       └── types/
│   │           └── index.ts      # TypeScript interfaces
│   ├── firestore.rules           # Security rules
│   ├── firestore.indexes.json    # Query indexes
│   ├── storage.rules
│   └── firebase.json             # Emulator config
│
└── README.md
```

## Modelli Dati

### Wine (Vino master)
```typescript
{
  id: string
  name: string           // "Barolo Monfortino"
  producer?: string      // "Giacomo Conterno"
  vintage?: number       // 2016
  type: WineType         // red, white, rosé, sparkling, dessert, fortified
  region?: string        // "Piemonte"
  country?: string       // "Italia"
  grapes?: string[]      // ["Nebbiolo"]
  alcohol?: number       // 14.5
}
```

### Bottle (Bottiglia fisica)
```typescript
{
  id: string
  wineId: string
  cellarId: string
  locationId?: string
  status: BottleStatus   // available, reserved, consumed, gifted
  acquiredAt?: Timestamp
  acquiredPrice?: number
  consumedAt?: Timestamp
}
```

### DinnerEvent (Cena pianificata)
```typescript
{
  id: string
  name: string
  date: Timestamp
  style: DinnerStyle     // informal, convivial, elegant
  cookingTime: CookingTime
  budgetLevel: BudgetLevel
  notes?: string         // RICHIESTE SPECIFICHE (priorità massima per AI)
  status: DinnerStatus
  menuProposal?: MenuProposal
}
```

### MenuProposal (Proposta menu generata)
```typescript
{
  courses: MenuCourse[]
  reasoning: string
  wineStrategy?: string  // "Due vini: bianco per antipasto/primo, rosso per secondo"
  seasonContext: string
  guestConsiderations: string[]
  totalPrepTime: number
  generatedAt: Timestamp
}
```

### MenuCourse (Portata con abbinamento vino)
```typescript
{
  course: CourseType     // starter, first, main, dessert
  name: string
  description: string
  dietaryFlags: string[] // ["GF", "LF", "V", "VG"]
  prepTime: number
  cellarWine?: {         // Vino dalla cantina
    name: string
    reasoning: string
  }
  marketWine?: {         // Vino da acquistare
    name: string
    details: string      // Tipo, regione, produttore
    reasoning: string
  }
}
```

## Funzionalità Principali

### 1. Gestione Cantina
- Visualizzazione inventario con filtri e ordinamento
- Ricerca vini per nome, produttore, regione
- Tracking posizione fisica (scaffale/riga/slot)
- Gestione stato bottiglie (disponibile, riservata, consumata)
- Seeding vini di esempio per testing

### 2. Scansione Etichette
- Cattura foto da camera o libreria
- OCR via Google Vision API
- Interpretazione AI dei dati estratti
- Fuzzy matching con vini esistenti
- Confidence score per ogni campo

### 3. Pianificazione Cene

**Comportamento:**
- Creazione evento con parametri (nome, data, stile, tempo cottura, budget)
- Campo `notes` per richieste specifiche dell'utente
- **Generazione AUTOMATICA del menu al salvataggio**
- Nessun bottone "Genera" - avviene in background

**Requisiti AI per generazione menu:**

1. **Richieste utente hanno PRIORITÀ MASSIMA**
   - Il campo `notes` viene passato all'AI come "RICHIESTE SPECIFICHE DELL'UTENTE"
   - Esempi: "Cucina giapponese", "Menu di pesce", "Tema autunnale con funghi"

2. **4 portate standard**: antipasto, primo, secondo, dolce

3. **Ogni portata ha DUE abbinamenti vino:**
   - `cellarWine`: vino dalla cantina dell'utente (obbligatorio se disponibile)
   - `marketWine`: vino da acquistare come alternativa

4. **Minimizzazione cambi vino:**
   - Stesso vino può coprire più portate (es. bianco per antipasto+primo)
   - Strategia esplicitata nel campo `wineStrategy`
   - Obiettivo: 2-3 vini massimo per cena

5. **Considerazioni aggiuntive:**
   - Stagione corrente
   - Stile cena (informale/conviviale/elegante)
   - Tempo di preparazione disponibile
   - Budget vini
   - Restrizioni alimentari ospiti

### 4. AI Sommelier (Chat)
- Chat conversazionale con Claude
- Tool calling per accesso a:
  - `search_wines`: ricerca vini in cantina
  - `get_wine_details`: dettagli vino specifico
  - `get_bottle_location`: posizione fisica bottiglia
  - `get_cellar_stats`: statistiche cantina
  - `get_friend_preferences`: preferenze alimentari amici

## Logging AI

Tutte le interazioni con Claude API vengono loggate per debug:

```
=== AI REQUEST (proposeDinnerMenu) ===
USER NOTES: [note utente o NESSUNA]
FULL PROMPT START ===
[prompt completo inviato all'AI]
FULL PROMPT END ===

=== AI RESPONSE (proposeDinnerMenu) ===
RESPONSE: [risposta JSON completa]
```

**Dove vedere i log:**
- Emulatore locale: http://127.0.0.1:4000/logs
- Produzione: Firebase Console > Functions > Logs

## Sviluppo Locale

### Prerequisiti
- macOS con Xcode 15+
- Node.js 20+
- Firebase CLI (`npm install -g firebase-tools`)
- Java 11+ (per emulatori Firestore)

### Setup

```bash
# Clone
git clone <repo>
cd personal_sommelier

# Firebase Functions
cd firebase/functions
npm install
npm run build

# Avvia emulatori (in un terminale separato)
cd ..
firebase emulators:start

# iOS - apri in Xcode
open ios/Convivio.xcodeproj
# Cmd+R per eseguire su simulatore
```

### Emulatori Firebase

| Servizio | Porta | UI |
|----------|-------|-----|
| Auth | 9099 | http://127.0.0.1:4000/auth |
| Firestore | 8080 | http://127.0.0.1:4000/firestore |
| Storage | 9199 | http://127.0.0.1:4000/storage |
| Functions | 5001 | http://127.0.0.1:4000/functions |
| Emulator UI | 4000 | http://127.0.0.1:4000 |

### Configurazione Emulatori iOS

L'app iOS rileva automaticamente il simulatore e si connette agli emulatori locali:

```swift
#if targetEnvironment(simulator)
let localhost = "127.0.0.1"
Auth.auth().useEmulator(withHost: localhost, port: 9099)
// ... altre configurazioni
#endif
```

## Configurazione

### Variabili d'ambiente (functions/.env)
```
ANTHROPIC_API_KEY=sk-ant-...
```

### Firebase Secrets (produzione)
```bash
firebase functions:secrets:set ANTHROPIC_API_KEY
```

## API Cloud Functions

### POST /extractWineFromPhoto
Estrae dati vino da foto etichetta.

**Input:**
```json
{
  "photoUrl": "gs://bucket/path/to/photo.jpg",
  "userId": "user123"
}
```

**Output:**
```json
{
  "success": true,
  "extraction": {
    "extractedFields": {
      "name": { "value": "Barolo", "confidence": 0.95 },
      "producer": { "value": "Conterno", "confidence": 0.88 }
    }
  },
  "suggestedMatches": [...]
}
```

### POST /proposeDinnerMenu
Genera menu con abbinamenti vino.

**Input:**
```json
{
  "dinnerId": "dinner123",
  "userId": "user123"
}
```

**Output:**
```json
{
  "success": true,
  "menu": {
    "courses": [...],
    "wineStrategy": "Due vini: Vermentino per antipasto e primo, Barolo per secondo",
    "reasoning": "..."
  },
  "wineProposals": {
    "available": [...],
    "suggested": [...]
  }
}
```

### POST /chatWithSommelier
Chat conversazionale con tool calling.

**Input:**
```json
{
  "message": "Che vino rosso mi consigli per una grigliata?",
  "conversationId": "conv123",
  "userId": "user123"
}
```

**Output:**
```json
{
  "success": true,
  "response": "Per una grigliata ti consiglio...",
  "conversationId": "conv123",
  "wineReferences": [...]
}
```

## Versioning

| Versione | Data | Descrizione |
|----------|------|-------------|
| v1.0 | 2026-01 | MVP iniziale |
| v1.1 | 2026-01 | Generazione menu automatica, abbinamenti vino per portata, minimizzazione cambi vino |

## Testing

### Test manuale su emulatore
1. Avvia emulatori: `firebase emulators:start`
2. Avvia app su simulatore iOS
3. Registra nuovo utente
4. Cantina > "Carica vini di esempio"
5. Cena > Crea nuova cena con note specifiche
6. Verifica generazione automatica menu
7. Controlla log su http://127.0.0.1:4000/logs

### Casi di test menu
- [ ] Menu senza note: genera menu standard stagionale
- [ ] Note "cucina giapponese": genera sushi, ramen, etc.
- [ ] Note "solo pesce": nessuna carne in menu
- [ ] Cantina vuota: solo marketWine proposti
- [ ] Cantina piena: cellarWine prioritari

## Licenza

MIT

## Autore

Mike - mikesoft.it
