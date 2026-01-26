# Convivio - Dinner Planning Feature

## Obiettivo
Implementare un flusso completo di pianificazione cena con generazione AI del menù e abbinamenti vino.

## Flusso Utente

### Fase 1: Input Cena
L'utente inserisce:
- **Descrizione sommaria** della cena (es. "cena romantica", "pranzo domenicale in famiglia", "cena di pesce estiva")
- **Numero di persone**
- **Eventuali restrizioni alimentari** (opzionale)

### Fase 2: Generazione Menù
L'AI genera un menù completo con:
- Antipasto (uno o più piatti)
- Primo
- Secondo
- Contorno (opzionale)
- Dolce (opzionale)

**Per ogni piatto generato:**
1. Nome del piatto
2. Breve descrizione
3. **Vino consigliato dalla cantina** - scelto tra i vini disponibili dell'utente
4. **Vino ideale (AI)** - l'abbinamento perfetto indipendentemente dalla cantina, con nome, produttore, annata consigliata

**Azioni per ogni piatto:**
- 🔄 **Rigenera piatto** - genera un'alternativa mantenendo lo stesso stile
- 🗑️ **Elimina piatto** - rimuove il piatto dal menù
- 🍷 **Rigenera vino** - propone un altro abbinamento (sia cantina che ideale)

### Regole Abbinamento Vini
**IMPORTANTE - Coerenza dei vini:**
- L'utente può scegliere: **"Stesso vino per tutto il pasto"** oppure **"Vini diversi per portata"**
- Se "Vini diversi":
  - Gli antipasti devono avere UN SOLO vino (mai cambiare vino a metà antipasto)
  - Possibilità di separare solo: Antipasti | Primi+Secondi | Dolce
  - Oppure: Antipasti | Primo | Secondo | Dolce
- Mai proporre più di 3-4 vini diversi per una cena

### Fase 3: Conferma e Consigli di Servizio
Quando l'utente preme **"Conferma Menù"**, genera la sezione **Consigli di Servizio**:

**Per ogni vino selezionato:**
- 🕐 **Quando aprirlo** - es. "Aprire 30 minuti prima di servire", "Decantare 1 ora prima"
- 🌡️ **Temperatura di servizio** - es. "16-18°C", "Servire fresco a 10-12°C"
- 🥂 **Bicchiere consigliato** - es. "Calice Borgogna", "Flûte", "Bicchiere da vino bianco"
- 📝 **Note aggiuntive** - es. "Non agitare, depositare verticalmente", "Perfetto dopo 2 ore dall'apertura"

**Se ci sono più vini:**
- Mostrare i consigli raggruppati per vino
- Indicare l'ordine di servizio
- Suggerire la sequenza temporale di apertura

## UI/UX Requirements

### Schermata Generazione Menù
```
┌─────────────────────────────────────┐
│ 🍽️ Il tuo menù                      │
├─────────────────────────────────────┤
│ ANTIPASTI                     🍷    │
│ ┌─────────────────────────────────┐ │
│ │ Carpaccio di tonno              │ │
│ │ con avocado e lime              │ │
│ │                                 │ │
│ │ 🏠 Dalla cantina: Perlugo       │ │
│ │ ⭐ Ideale: Vermentino di        │ │
│ │    Gallura DOCG 2022            │ │
│ │                                 │ │
│ │ [🔄] [🗑️] [🍷]                  │ │
│ └─────────────────────────────────┘ │
│                                     │
│ PRIMO                         🍷    │
│ ┌─────────────────────────────────┐ │
│ │ Risotto alla milanese           │ │
│ │ ...                             │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ─────────────────────────────────── │
│ 🍷 Strategia vini:                  │
│ ○ Stesso vino per tutto            │
│ ● Vini diversi per portata         │
│                                     │
│        [✓ Conferma Menù]            │
└─────────────────────────────────────┘
```

### Schermata Consigli di Servizio
```
┌─────────────────────────────────────┐
│ 🍷 Consigli di Servizio             │
├─────────────────────────────────────┤
│                                     │
│ 1. PERLUGO - Pievalta              │
│    Per: Antipasti                   │
│    ┌───────────────────────────────┐│
│    │ 🕐 Aprire 15 min prima       ││
│    │ 🌡️ Servire a 8-10°C          ││
│    │ 🥂 Flûte o calice bianco     ││
│    │ 📝 Servire ben freddo        ││
│    └───────────────────────────────┘│
│                                     │
│ 2. SFURSAT 5 STELLE - Nino Negri   │
│    Per: Primo, Secondo              │
│    ┌───────────────────────────────┐│
│    │ 🕐 Decantare 1 ora prima     ││
│    │ 🌡️ Servire a 16-18°C         ││
│    │ 🥂 Calice Borgogna ampio     ││
│    │ 📝 Vino importante, lasciare ││
│    │    respirare nel decanter    ││
│    └───────────────────────────────┘│
│                                     │
│ ⏱️ TIMELINE APERTURA:               │
│ • -1h 30min: Aprire Sfursat        │
│ • -1h 00min: Decantare Sfursat     │
│ • -15min: Aprire Perlugo           │
│                                     │
│      [📤 Condividi] [✓ Salva]       │
└─────────────────────────────────────┘
```

## Integrazione con Cantina
- Recuperare l'inventario vini dell'utente da Firestore
- Per ogni vino in cantina, considerare:
  - Tipo (rosso, bianco, spumante, etc.)
  - Annata
  - Rating dell'utente (se presente)
  - Quantità disponibile (non proporre se c'è solo 1 bottiglia, a meno che non sia l'unica opzione)

## Cloud Function: proposeDinnerMenu
La function deve:
1. Ricevere: descrizione, numero persone, restrizioni, inventario cantina, strategia vini
2. Chiamare Claude per generare il menù
3. Per ogni piatto, fare match con i vini in cantina
4. Ritornare: menù completo con abbinamenti

## Cloud Function: generateServiceRecommendations
La function deve:
1. Ricevere: lista vini selezionati, orario cena
2. Chiamare Claude per generare consigli di servizio
3. Ritornare: consigli per ogni vino + timeline

## Note Implementative
- Usare SwiftUI per le view
- Salvare il menù generato in Firestore sotto `users/{uid}/dinners/{dinnerId}`
- Permettere di modificare e rigenerare singoli elementi senza perdere il resto
- Implementare animazioni fluide per aggiunta/rimozione piatti
