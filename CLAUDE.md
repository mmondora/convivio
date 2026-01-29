# CLAUDE.md — Istruzioni per Claude Code

## Panoramica Progetto

**Convivio** è un'app iOS per la gestione della cantina vini personale con AI sommelier integrato.

### Stack Tecnologico
- **iOS**: SwiftUI, Swift Concurrency, iOS 17+
- **Backend**: Firebase Cloud Functions Gen2, TypeScript, Node 20
- **Database**: Firestore
- **Auth**: Firebase Auth (Apple, Google, Email)
- **AI**: Anthropic Claude API (claude-sonnet-4-20250514)
- **OCR**: Google Vision API

## Struttura Progetto

```
personal_sommelier/
├── ios/Convivio/           # App iOS SwiftUI
│   ├── Views/              # Viste SwiftUI
│   ├── Models/             # Data models
│   └── Services/           # AuthManager, FirebaseService
├── firebase/
│   ├── functions/src/      # Cloud Functions TypeScript
│   │   ├── api/            # Endpoints HTTP (extract, propose, chat, health)
│   │   ├── triggers/       # Firestore triggers
│   │   └── types/          # TypeScript interfaces
│   ├── firestore.rules     # Security rules
│   └── firebase.json       # Config emulatori
├── CONTEXT.md              # Contesto dettagliato progetto
├── PROMPT.md               # Prompt AI per funzionalità
└── README.md               # Documentazione completa
```

## Comandi Utili

### Firebase Functions
```bash
cd firebase/functions
npm install              # Installa dipendenze
npm run build            # Compila TypeScript
npm run lint             # Lint codice
```

### Emulatori Firebase
```bash
cd firebase
firebase emulators:start  # Avvia tutti gli emulatori
# UI: http://127.0.0.1:4000
# Functions: http://127.0.0.1:5001
# Firestore: http://127.0.0.1:8080
```

### iOS
```bash
open ios/Convivio.xcodeproj  # Apri in Xcode
# Cmd+R per eseguire su simulatore
```

## Convenzioni Codice

### Lingua
- **Codice**: Inglese (variabili, funzioni, commenti tecnici)
- **UI strings**: Italiano (testi visibili all'utente)

### Swift (iOS)
- SwiftUI con async/await
- @MainActor per ViewModels
- Pattern MVVM

### TypeScript (Functions)
- Strict mode abilitato
- Validazione input con Zod
- Tipi espliciti, no `any`

### Commit Style
Usa prefissi emoji:
- 🍷 `feat:` nuova funzionalità
- 🐛 `fix:` bug fix
- 📝 `docs:` documentazione
- ♻️ `refactor:` refactoring
- ✅ `test:` test

## Data Model Principali

- **Wine**: Record master vino (nome, produttore, annata, tipo)
- **Bottle**: Bottiglia fisica con location e status
- **DinnerEvent**: Cena pianificata con ospiti
- **MenuProposal**: Menu generato con abbinamenti vino per portata

## API Cloud Functions

| Endpoint | Descrizione |
|----------|-------------|
| `POST /extractWineFromPhoto` | OCR etichetta + interpretazione AI |
| `POST /proposeDinnerMenu` | Genera menu con abbinamenti vino |
| `POST /chatWithSommelier` | Chat AI con tool calling |
| `GET /healthCheck` | Health check |

## Variabili d'Ambiente

File `firebase/functions/.env`:
```
ANTHROPIC_API_KEY=sk-ant-...
```

## Note Importanti

1. **L'app iOS si connette automaticamente agli emulatori** quando in esecuzione su simulatore
2. **Generazione menu è automatica** al salvataggio della cena (no bottone "Genera")
3. **Il campo `notes` della cena ha PRIORITÀ MASSIMA** per l'AI nella generazione menu
4. **Ogni portata ha DUE abbinamenti vino**: uno dalla cantina, uno da acquistare
5. **Logging AI**: tutte le chiamate Claude sono loggate per debug

## Documentazione Aggiuntiva

- `README.md`: Overview completa, API contracts, data models
- `CONTEXT.md`: ADRs, decisioni architetturali, stato implementazione
- `PROMPT.md`: Prompt utilizzati per le funzionalità AI
