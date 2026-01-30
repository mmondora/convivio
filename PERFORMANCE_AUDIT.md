# Performance Audit Report - Convivio iOS App

**Data**: Gennaio 2026
**Versione analizzata**: 1.3.0

---

## Executive Summary

L'analisi ha identificato diversi problemi di performance e memoria che impattano l'esperienza utente. Le aree critiche sono:

1. **API Calls**: Nessuno streaming, nessuna cache, modello costoso per task semplici
2. **UI Performance**: Mancanza di lazy loading e paginazione per liste lunghe
3. **Memory Management**: Pattern potenzialmente problematici con @Published e closures

---

## PARTE 1: Analisi API Calls

### 1.1 Modello OpenAI

| Aspetto | Stato Attuale | Problema |
|---------|---------------|----------|
| Modello | `gpt-4o` per tutto | Costoso e lento per task semplici |
| Max tokens | 16,000 (menu) | Molto alto, aumenta latenza |
| Streaming | Non implementato | Utente aspetta risposta completa |
| Cache | Nessuna | Stesse richieste rigenerate |
| Timeout | 5 minuti | Può sembrare "bloccato" |

### 1.2 Endpoint e utilizzo

```
OpenAIService.swift:
- extractWineFromPhoto() → gpt-4o vision
- chatWithSommelier() → gpt-4o (max 1000 tokens)
- proposeDinnerMenu() → delegato a MenuGeneratorService

MenuGeneratorService.swift:
- generateMenu() → gpt-4o (max 16000 tokens)
- regenerateDish() → gpt-4o
- generateDetailedMenu() → gpt-4o
- generateInvite() → gpt-4o
```

### 1.3 Raccomandazioni

- **gpt-4o-mini** per: rigenerazione piatto, inviti, chat semplici
- **gpt-4o** per: menu completo, dettaglio menu con ricette
- Implementare streaming per feedback progressivo
- Cache con TTL per risposte ripetute

---

## PARTE 2: Analisi SwiftUI Views

### 2.1 Lazy Loading

| View | Pattern Attuale | Problema |
|------|-----------------|----------|
| CellarView | `List { ForEach }` | Nessuna paginazione |
| FoodView | `List { ForEach }` | Carica tutte le cene |
| DettaglioMenuView | `LazyVStack` | OK |
| ChatView | `LazyVStack` | OK |

### 2.2 Frame Heights Hard-coded

```swift
// FoodView.swift:718
.frame(minHeight: CGFloat(menu.menu.allCourses.reduce(0) {...}) * 130 + ...)

// FoodView.swift:1081
.frame(minHeight: CGFloat(wineCount) * 80 + ...)
```

**Problema**: Forza il rendering di tutti gli elementi per calcolare l'altezza.

### 2.3 Computed Properties Costose

```swift
// CellarView.swift:24-83
var filteredBottles: [Bottle] {
    // Filtraggio e sorting complesso
    // Ricalcolato ad ogni update della view
}
```

### 2.4 Paginazione Mancante

| Lista | Elementi Tipici | Paginazione |
|-------|-----------------|-------------|
| Cantina vini | 10-500+ | NO |
| Cene | 10-100+ | NO |
| Chat messages | 10-100+ | NO (solo scroll) |
| Valutazioni | Variable | NO |

---

## PARTE 3: Analisi Memory Management

### 3.1 @Published su Collezioni

```swift
// CellarManager.swift
@Published var availableCellars: [Cellar] = []  // Array di oggetti complessi

// SharingService.swift
@Published var pendingInvitations: [CKShare.Metadata] = []
```

**Rischio**: Ogni modifica triggera re-render di tutti i subscriber.

### 3.2 [weak self] Mancante

```swift
// DettaglioMenuView.swift:56
Task { await generateDetailedMenu() }  // self implicito

// ChatView.swift:140
Task { await getAIResponse(for: messageText) }  // self implicito
```

### 3.3 Thread Safety

```swift
// LanguageManager.swift - MANCA @MainActor
class LanguageManager: ObservableObject {
    @Published var currentLanguage: AppLanguage  // Possibili race condition
}
```

### 3.4 Singleton Pattern

11 singleton identificati, di cui 7 ObservableObject. Pattern corretto ma attenzione a:
- Non usare `@ObservedObject` per singleton (usare accesso diretto o EnvironmentObject)
- Garantire cleanup su navigazione

---

## PARTE 4: Loading UX

### 4.1 Pattern Attuali

| Pattern | Implementazione | Coverage |
|---------|-----------------|----------|
| ProgressView | Semplice cerchio | 6 views |
| Skeleton | Non implementato | 0 |
| Streaming text | Non implementato | 0 |
| Timeout message | Non implementato | 0 |

### 4.2 Aree Senza Feedback

- Wine matching in ChatView
- Location suggestions in forms
- Menu generation (solo spinner generico)

---

## Piano di Implementazione

### Commit 1: Lazy Loading e Paginazione
- [ ] Convertire VStack in LazyVStack dove necessario
- [ ] Implementare paginazione per cantina (20 item)
- [ ] Implementare paginazione per cene (20 item)
- [ ] Rimuovere frame heights hard-coded

### Commit 2: Selezione Modello Intelligente
- [ ] Aggiungere `modelOverride` a PromptTemplate
- [ ] Usare gpt-4o-mini per task semplici
- [ ] Mantenere gpt-4o per task complessi

### Commit 3: Streaming Responses
- [ ] Implementare streaming in OpenAIService
- [ ] Aggiungere callback per chunk progressivi
- [ ] Integrare in UI per feedback real-time

### Commit 4: Cache API
- [ ] Implementare APICacheService
- [ ] Hash-based keys (prompt + params)
- [ ] TTL configurabile, max 50 entries, LRU eviction

### Commit 5: Compressione Prompt
- [ ] Audit di tutti i prompt
- [ ] Rimuovere ridondanze
- [ ] Target: -30% token

### Commit 6: Audit Memory
- [ ] Aggiungere @MainActor a LanguageManager
- [ ] Verificare [weak self] in closures
- [ ] Ottimizzare @Published

### Commit 7: UX Caricamento
- [ ] Skeleton views
- [ ] Progress contestuale
- [ ] Timeout con messaggio

### Commit 8: Monitoring Debug
- [ ] Log tempi API
- [ ] Indicatore memoria in debug mode

---

## Metriche Target

| Metrica | Attuale | Target |
|---------|---------|--------|
| Tempo generazione menu | ~30s | <15s (con streaming) |
| Memoria peak | Non misurata | <200MB |
| Token per menu | ~10,000 | ~7,000 (-30%) |
| Re-render inutili | Frequenti | Minimizzati |
