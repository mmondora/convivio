# Convivio - Ralph Loop Task

## Progetto

**Convivio** è un'app iOS per la gestione della cantina personale con:
- Gestione vini e bottiglie (con scansione etichette OCR)
- Organizzazione cantina e posizioni
- Rating e profili di gusto
- Pianificazione cene con proposte menu/abbinamenti
- Gestione amici e preferenze alimentari
- Chat con assistente AI
- Backend Firebase (Firestore + Auth)

**Stack**: SwiftUI, Firebase (Firestore, Auth), iOS 17+

**Struttura**:
```
ios/Convivio/
├── ConvivioApp.swift          # Entry point
├── Models/Models.swift        # Data models (Wine, Bottle, Cellar, etc.)
├── Services/
│   ├── AuthManager.swift      # Autenticazione
│   └── FirebaseService.swift  # Operazioni Firestore
└── Views/
    ├── AuthenticationView.swift
    ├── CellarView.swift
    ├── ChatView.swift
    ├── DinnerListView.swift
    ├── ProfileView.swift
    └── ScanView.swift
```

---

## Task Corrente

<!-- Descrivi qui il task da completare -->

**Obiettivo**: [Descrivi cosa deve essere implementato/fixato]

**Contesto**: [Perché serve, qual è il problema attuale]

**Requisiti**:
- [ ] Requisito 1
- [ ] Requisito 2
- [ ] Requisito 3

**Criteri di accettazione**:
- [ ] Il codice compila senza errori
- [ ] [Criterio specifico 1]
- [ ] [Criterio specifico 2]

---

## Vincoli

- Usa SwiftUI idiomatico (no UIKit wrapping se non necessario)
- Mantieni la struttura esistente dei Models
- Rispetta le convenzioni di naming in italiano per displayName/UI
- Non modificare lo schema Firestore esistente senza motivo
- Testa su iOS 17+

---

## Segnale di Completamento

Quando il task è completato con successo, scrivi:

```
LOOP_COMPLETE
```

---

## Note per Ralph

1. **Fresh context**: Ogni iterazione rilegge questo file - mantienilo aggiornato
2. **Disk is state**: Usa file `.agent/scratchpad.md` per note tra iterazioni
3. **Build check**: Verifica che il progetto compili con `xcodebuild`
4. **Non assumere**: Cerca nel codebase prima di dire "non implementato"

---

## Esempi di Task

### Esempio 1: Nuovo Feature
```markdown
**Obiettivo**: Aggiungere filtro per tipo di vino nella CellarView

**Requisiti**:
- [ ] Picker per selezionare WineType (o "Tutti")
- [ ] Filtrare la lista vini in base alla selezione
- [ ] Persistere la selezione in UserDefaults

**Criteri di accettazione**:
- [ ] Il filtro funziona per tutti i WineType
- [ ] "Tutti" mostra l'intera lista
- [ ] La selezione persiste al riavvio app
```

### Esempio 2: Bug Fix
```markdown
**Obiettivo**: Fixare crash quando si aggiunge bottiglia senza vintage

**Contesto**: L'app crasha se vintage è nil durante il salvataggio

**Requisiti**:
- [ ] Gestire vintage opzionale correttamente
- [ ] Validare input prima del salvataggio

**Criteri di accettazione**:
- [ ] Nessun crash con vintage nil
- [ ] Bottiglia salvata correttamente su Firestore
```

### Esempio 3: Refactoring
```markdown
**Obiettivo**: Estrarre logica di validazione Wine in extension separata

**Requisiti**:
- [ ] Creare Wine+Validation.swift
- [ ] Spostare logica validate() esistente
- [ ] Aggiungere validazione per campi obbligatori

**Criteri di accettazione**:
- [ ] Tutti i test esistenti passano
- [ ] Nuova struttura file pulita
```
