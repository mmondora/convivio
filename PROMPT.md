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

## Backlog Task (Priorità MVP)

### FASE 1 - Core UX Enhancement (Must Have)

#### Task 1.1: Voto Rapido + Profilo Sensoriale UI
**Obiettivo**: Implementare UI completa per rating rapido e profilo sensoriale

**Contesto**: Il modello TasteProfile esiste ma non c'è UI per compilarlo. L'utente deve poter votare un vino in <30s con profilo sensoriale visivo.

**Requisiti**:
- [ ] QuickRatingSheet: overlay rapido con stelle (1-5) + toggle favorito
- [ ] TasteProfileEditor: slider visivi per acidità, tannino, corpo, dolcezza, effervescenza
- [ ] Visualizzazione radar chart del profilo sensoriale
- [ ] Salvataggio TasteProfile in Firestore
- [ ] Accessibile da WineDetailView e post-consumo

**Criteri di accettazione**:
- [ ] Rating completo in <30 secondi
- [ ] Profilo sensoriale salvato correttamente
- [ ] Radar chart visualizza profilo
- [ ] Il codice compila senza errori

---

#### Task 1.2: "Dov'è la bottiglia?" - Ricerca Posizione
**Obiettivo**: Implementare ricerca rapida per localizzare fisicamente una bottiglia

**Contesto**: L'utente deve trovare subito dove si trova una bottiglia specifica nella cantina.

**Requisiti**:
- [ ] Search bar prominente in CellarView o funzione dedicata
- [ ] Ricerca per nome vino, produttore, vintage
- [ ] Risultato mostra: nome vino + posizione esatta (cantina > scaffale > riga > slot)
- [ ] Highlight visivo della posizione
- [ ] Integrazione con Siri Shortcuts (opzionale)

**Criteri di accettazione**:
- [ ] Ricerca trova bottiglia per nome parziale
- [ ] Posizione visualizzata chiaramente (es. "Scaffale A, Riga 2, Slot 5")
- [ ] Funziona anche con query da chat AI ("Dove trovo il Barolo?")

---

#### Task 1.3: Storico Consumi Visualizzato
**Obiettivo**: Visualizzare lo storico dei movimenti/consumi delle bottiglie

**Contesto**: I movements esistono in Firestore ma non sono visualizzati. L'utente vuole vedere cosa ha consumato e quando.

**Requisiti**:
- [ ] Vista MovementHistoryView con lista consumi
- [ ] Filtri per periodo (settimana, mese, anno)
- [ ] Raggruppamento per vino o per data
- [ ] Stats: bottiglie consumate, valore totale, tipi più bevuti
- [ ] Accessibile da ProfileView o tab dedicata

**Criteri di accettazione**:
- [ ] Lista consumi mostra data, vino, occasione
- [ ] Filtri funzionano correttamente
- [ ] Stats calcolate in modo accurato

---

### FASE 2 - Dinner & Service Enhancement (Must Have)

#### Task 2.1: Tab Proposte + Sistema Proposta Vini
**Obiettivo**: Implementare la quinta tab "Proposte" con sistema di proposta vini per cene

**Contesto**: Manca la tab Proposte dalla tab bar. Serve per condividere proposte vini e raccogliere voti.

**Requisiti**:
- [ ] Nuova tab "Proposte" in MainTabView
- [ ] ProposalsView: lista proposte attive per le prossime cene
- [ ] ProposalDetailView: mostra vini proposti con pulsante voto
- [ ] Distinguere chiaramente "Disponibile in cantina" vs "Suggerito acquisto"
- [ ] WineProposal model già esiste, collegare a UI

**Criteri di accettazione**:
- [ ] Tab Proposte visibile e funzionante
- [ ] Proposte collegate a DinnerEvent
- [ ] Distinzione visiva chiara tra vini disponibili/da comprare

---

#### Task 2.2: Servizio Vino - Checklist e Promemoria
**Obiettivo**: Implementare checklist servizio vino con temperature e promemoria

**Contesto**: Per ogni vino scelto per una cena, l'utente deve sapere: temperatura target, tempo raffreddamento, decantazione, orario apertura, bicchiere.

**Requisiti**:
- [ ] ServiceChecklist model: temperatura, tempoRaffreddamento, decantazione, oraApertura, tipoBicchiere
- [ ] WineServiceView: checklist interattiva con timeline
- [ ] Calcolo automatico tempi basato su tipo vino e temperatura attuale
- [ ] Integrazione notifiche locali iOS (UserNotifications)
- [ ] Promemoria: "Metti in fresco", "Apri per decantare", "Pronto per servire"

**Criteri di accettazione**:
- [ ] Checklist generata per vini selezionati
- [ ] Notifiche iOS funzionano
- [ ] Timeline visiva con countdown
- [ ] Suggerimenti temperatura per tipo vino

---

#### Task 2.3: Miglioramento Pianificazione Cena + LLM Constraints
**Obiettivo**: Rafforzare i vincoli LLM nella generazione menu e abbinamenti

**Contesto**: Il prompt richiede vincoli forti: non proporre vini non disponibili come "hai già", distinguere chiaramente "disponibile" vs "da comprare".

**Requisiti**:
- [ ] Aggiornare prompt Cloud Function generateMenuProposal
- [ ] Passare inventory completo con disponibilità alla Cloud Function
- [ ] Output strutturato con sezioni separate: "Dalla tua cantina" / "Consigliati da acquistare"
- [ ] Reasoning per ogni proposta vino
- [ ] Validazione: se propone vino "disponibile" deve esistere in cantina

**Criteri di accettazione**:
- [ ] Mai proposti vini inesistenti come "disponibili"
- [ ] Chiara separazione visiva delle due categorie
- [ ] Reasoning spiega perché quel vino per quel piatto

---

### FASE 3 - External Data & Advanced (Should Have)

#### Task 3.1: Schede Vino Esterne (Vivino, Tannico)
**Obiettivo**: Integrare informazioni esterne sui vini da fonti specializzate

**Contesto**: Ogni vino deve avere scheda informativa con descrizione professionale, punteggi medi, stile del vino. Separare dati editoriali da rating personali.

**Requisiti**:
- [ ] ExternalWineSource model: source, apiEndpoint, lastSync
- [ ] WineEditorialProfile model: description, avgRating, style, awards, sourceUrl
- [ ] Integrazione API Vivino (se disponibile) o fallback web scraping etico
- [ ] Cache locale con TTL (non chiamare API ad ogni visualizzazione)
- [ ] WineDetailView sezione "Info Esterne" separata da rating personale
- [ ] Indicatore fonte dati e data ultimo aggiornamento

**Criteri di accettazione**:
- [ ] Almeno 1 fonte esterna funzionante
- [ ] Dati cachati correttamente
- [ ] Separazione visiva dati esterni vs personali
- [ ] Fallback se API non disponibile (mostra "Info non disponibili")

---

#### Task 3.2: Sistema Condivisione + Voto Remoto Guest
**Obiettivo**: Permettere agli amici di votare proposte vini via link senza accesso app

**Contesto**: Il Guest/Friend remoto non vede la cantina completa, ma può inserire preferenze e votare proposte via link.

**Requisiti**:
- [ ] Generazione link univoco per proposta (Firebase Dynamic Links o custom URL)
- [ ] GuestVotingWebView: pagina web minimale per votare (no login richiesto)
- [ ] Raccolta preferenze alimentari base via form semplice
- [ ] Aggregazione voti per proposta
- [ ] Notifica owner quando guest vota

**Criteri di accettazione**:
- [ ] Link funziona da browser mobile/desktop
- [ ] Voto salvato e visibile a owner
- [ ] Guest non vede inventario completo
- [ ] Privacy: guest vede solo proposta specifica

---

#### Task 3.3: Ricerca Avanzata e Filtri
**Obiettivo**: Implementare ricerca avanzata con filtri multipli

**Contesto**: La ricerca attuale è solo per nome. Servono filtri per tipo, regione, vintage, rating, disponibilità.

**Requisiti**:
- [ ] AdvancedSearchView con filtri combinabili
- [ ] Filtri: tipo vino, regione, paese, vintage range, rating min, solo disponibili
- [ ] Ordinamento: nome, vintage, rating, data aggiunta
- [ ] Salvataggio filtri preferiti
- [ ] Query Firestore ottimizzate con indici compositi

**Criteri di accettazione**:
- [ ] Filtri combinabili funzionano correttamente
- [ ] Performance accettabile (<1s per query)
- [ ] UI intuitiva per applicare/rimuovere filtri

---

#### Task 3.4: Statistiche Gusto Personali
**Obiettivo**: Analizzare e visualizzare le preferenze di gusto dell'utente

**Contesto**: L'utente vuole capire i propri gusti basandosi sui rating e profili sensoriali.

**Requisiti**:
- [ ] TasteStatsView: dashboard preferenze personali
- [ ] Analisi: tipi vino preferiti, regioni preferite, profilo sensoriale medio
- [ ] Grafici: distribuzione rating, radar chart profilo medio
- [ ] Trend: evoluzione gusti nel tempo
- [ ] Accessibile da ProfileView

**Criteri di accettazione**:
- [ ] Stats calcolate da rating e tasteProfiles esistenti
- [ ] Grafici visualizzano dati correttamente
- [ ] Insight utili (es. "Preferisci rossi corposi con tannino medio-alto")

---

### FASE 4 - Multi-Platform & Polish (Nice to Have)

#### Task 4.1: Web App Base
**Obiettivo**: Creare web app per gestione, pianificazione, overview

**Contesto**: Il prompt richiede Web + iOS. La web app serve per gestione più complessa (overview, report, export).

**Requisiti**:
- [ ] Setup progetto web (React/Next.js o Vue)
- [ ] Autenticazione Firebase condivisa
- [ ] Dashboard overview: stats cantina, prossime cene
- [ ] Gestione cantine (CRUD completo)
- [ ] Export dati (CSV, PDF)
- [ ] Deploy su Google Cloud (Cloud Run o Firebase Hosting)

**Criteri di accettazione**:
- [ ] Login con stesse credenziali iOS
- [ ] Dati sincronizzati in tempo reale
- [ ] Responsive design
- [ ] Deploy funzionante su free tier

---

## Task Corrente

<!-- Seleziona un task dal backlog sopra e copia qui per lavorarci -->

**Obiettivo**: [Copia da task selezionato]

**Contesto**: [Copia da task selezionato]

**Requisiti**:
- [ ] [Copia da task selezionato]

**Criteri di accettazione**:
- [ ] Il codice compila senza errori
- [ ] [Copia da task selezionato]

---

## Vincoli

- Usa SwiftUI idiomatico (no UIKit wrapping se non necessario)
- Mantieni la struttura esistente dei Models
- Rispetta le convenzioni di naming in italiano per displayName/UI
- Non modificare lo schema Firestore esistente senza motivo
- Testa su iOS 17+
- Preferisci editing file esistenti a creazione nuovi file
- Se una feature non è usabile davvero, proponi di tagliarla dall'MVP

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
5. **Un task alla volta**: Seleziona UN task dal backlog, copialo in "Task Corrente", completalo, poi passa al successivo

---

## Documentazione Richiesta (da generare)

I seguenti documenti devono essere creati nella cartella `docs/`:

1. **docs/PRD.md** - Product Requirements Document sintetico
2. **docs/UX-MOCKUPS.md** - Mockup UX testuali per ogni schermata
3. **docs/DATA-MODEL.md** - ER diagram testuale con entità e relazioni
4. **docs/ROADMAP.md** - Roadmap 3 fasi con milestone
5. **docs/CHECKLIST-AVVIO.md** - Checklist avvio progetto

---

## Riepilogo Gap Analysis

| Stato | Feature |
|-------|---------|
| ✅ | App iOS base (4 tab) |
| ✅ | DB Firestore |
| ✅ | Scan etichette OCR |
| ✅ | Gestione bottiglie |
| ✅ | Location scaffale/riga/slot |
| ✅ | Rating base 1-5 |
| ✅ | Model TasteProfile |
| ✅ | Amici + Preferenze alimentari |
| ✅ | Pianificazione cena base |
| ✅ | Chat AI Sommelier |
| ❌ | Tab Proposte |
| ❌ | UI TasteProfile/Voto rapido |
| ❌ | "Dov'è la bottiglia?" |
| ❌ | Storico consumi visualizzato |
| ❌ | Servizio vino + promemoria |
| ❌ | Schede vino esterne |
| ❌ | Condivisione + Voto remoto |
| ❌ | Ricerca avanzata |
| ❌ | Statistiche gusto |
| ❌ | Web app |
| ❌ | Documentazione PRD/UX/ER |
