import Foundation

// MARK: - Wine Temperature Category

/// Temperature categories for wine service with fridge timing
enum WineTemperatureCategory: String, Codable, CaseIterable, Identifiable {
    case bollicine = "bollicine"              // 6-8°C - 3 hours in fridge
    case biancoLeggero = "bianco_leggero"     // 8-10°C - 2.5 hours
    case rosato = "rosato"                     // 10-12°C - 2 hours
    case biancoStrutturato = "bianco_strutturato" // 12-14°C - 1.5 hours
    case rossoLeggero = "rosso_leggero"       // 14-16°C - 30 min in fridge
    case rossoStrutturato = "rosso_strutturato"  // 16-18°C - no fridge needed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bollicine: return "Bollicine"
        case .biancoLeggero: return "Bianco Leggero"
        case .rosato: return "Rosato"
        case .biancoStrutturato: return "Bianco Strutturato"
        case .rossoLeggero: return "Rosso Leggero"
        case .rossoStrutturato: return "Rosso Strutturato"
        }
    }

    var servingTemperature: String {
        switch self {
        case .bollicine: return "6-8°C"
        case .biancoLeggero: return "8-10°C"
        case .rosato: return "10-12°C"
        case .biancoStrutturato: return "12-14°C"
        case .rossoLeggero: return "14-16°C"
        case .rossoStrutturato: return "16-18°C"
        }
    }

    var icon: String {
        switch self {
        case .bollicine: return "bubbles.and.sparkles"
        case .biancoLeggero, .biancoStrutturato: return "wineglass"
        case .rosato: return "drop.circle"
        case .rossoLeggero, .rossoStrutturato: return "wineglass.fill"
        }
    }

    /// Minutes the wine should spend in the fridge before serving
    var fridgeMinutes: Int {
        switch self {
        case .bollicine: return 180        // 3 hours
        case .biancoLeggero: return 150    // 2.5 hours
        case .rosato: return 120           // 2 hours
        case .biancoStrutturato: return 90 // 1.5 hours
        case .rossoLeggero: return 30      // 30 minutes
        case .rossoStrutturato: return 0   // No fridge needed
        }
    }

    /// Minutes before serving to take the wine out of the fridge
    /// (to let it warm up slightly to ideal temperature)
    var takeOutMinutes: Int {
        switch self {
        case .bollicine: return 5          // Keep very cold
        case .biancoLeggero: return 10
        case .rosato: return 15
        case .biancoStrutturato: return 20
        case .rossoLeggero: return 0       // Serve immediately after brief chill
        case .rossoStrutturato: return 0   // Room temperature
        }
    }

    /// Whether this wine needs refrigeration
    var needsFridge: Bool {
        fridgeMinutes > 0
    }

    /// Detailed serving instructions
    var servingInstructions: String {
        switch self {
        case .bollicine:
            return "Metti in frigo 3 ore prima. Servi immediatamente."
        case .biancoLeggero:
            return "Metti in frigo 2.5 ore prima. Togli 10 minuti prima di servire."
        case .rosato:
            return "Metti in frigo 2 ore prima. Togli 15 minuti prima di servire."
        case .biancoStrutturato:
            return "Metti in frigo 1.5 ore prima. Togli 20 minuti prima di servire."
        case .rossoLeggero:
            return "Metti in frigo 30 minuti prima di servire."
        case .rossoStrutturato:
            return "Servi a temperatura ambiente (16-18°C). Non refrigerare."
        }
    }

    /// Suggested category based on wine type
    static func suggested(for wineType: WineType) -> WineTemperatureCategory {
        switch wineType {
        case .sparkling: return .bollicine
        case .white: return .biancoLeggero
        case .rose: return .rosato
        case .red: return .rossoStrutturato
        case .dessert: return .biancoStrutturato
        case .fortified: return .rossoStrutturato
        }
    }
}

// MARK: - Confirmed Wine

/// A wine confirmed for a dinner with temperature and notification settings
struct ConfirmedWine: Codable, Identifiable {
    let id: UUID
    let wineId: String?           // ID from cellar (nil if purchase suggestion)
    let wineName: String
    let producer: String?
    let vintage: String?
    let wineType: String
    let course: String            // Associated course (antipasti, primi, etc.)
    var temperatureCategory: WineTemperatureCategory
    var putInFridgeNotificationId: String?
    var takeOutNotificationId: String?
    var isFromCellar: Bool
    var quantity: Int

    init(
        id: UUID = UUID(),
        wineId: String? = nil,
        wineName: String,
        producer: String? = nil,
        vintage: String? = nil,
        wineType: String,
        course: String,
        temperatureCategory: WineTemperatureCategory,
        isFromCellar: Bool,
        quantity: Int = 1
    ) {
        self.id = id
        self.wineId = wineId
        self.wineName = wineName
        self.producer = producer
        self.vintage = vintage
        self.wineType = wineType
        self.course = course
        self.temperatureCategory = temperatureCategory
        self.putInFridgeNotificationId = nil
        self.takeOutNotificationId = nil
        self.isFromCellar = isFromCellar
        self.quantity = quantity
    }

    var displayName: String {
        var parts: [String] = []
        if let producer = producer {
            parts.append(producer)
        }
        parts.append(wineName)
        if let vintage = vintage {
            parts.append(vintage)
        }
        return parts.joined(separator: " ")
    }

    var hasScheduledNotifications: Bool {
        putInFridgeNotificationId != nil || takeOutNotificationId != nil
    }

    /// Create from a menu wine pairing
    static func from(pairing: MenuWinePairing) -> ConfirmedWine {
        let wineTypeString = "red" // Default, could be improved with AI detection
        let suggestedTemp = WineTemperatureCategory.rossoStrutturato

        return ConfirmedWine(
            wineId: nil,
            wineName: pairing.vino.nome,
            producer: pairing.vino.produttore,
            vintage: pairing.vino.annata,
            wineType: wineTypeString,
            course: pairing.portata,
            temperatureCategory: suggestedTemp,
            isFromCellar: pairing.vino.provenienza == .cantina,
            quantity: pairing.vino.quantitaNecessaria
        )
    }

    /// Create from a wine suggestion (to purchase)
    static func from(suggestion: WineSuggestion, course: String) -> ConfirmedWine {
        return ConfirmedWine(
            wineId: nil,
            wineName: suggestion.vino,
            producer: suggestion.produttore,
            vintage: suggestion.annata,
            wineType: "red",
            course: course,
            temperatureCategory: .rossoStrutturato,
            isFromCellar: false,
            quantity: 1
        )
    }
}

// MARK: - Wine Confirmation Summary

/// Summary of confirmed wines for a dinner
struct WineConfirmationSummary {
    let confirmedWines: [ConfirmedWine]
    let dinnerDate: Date

    var totalBottles: Int {
        confirmedWines.reduce(0) { $0 + $1.quantity }
    }

    var cellarWinesCount: Int {
        confirmedWines.filter { $0.isFromCellar }.count
    }

    var purchaseWinesCount: Int {
        confirmedWines.filter { !$0.isFromCellar }.count
    }

    var winesNeedingFridge: [ConfirmedWine] {
        confirmedWines.filter { $0.temperatureCategory.needsFridge }
    }

    /// Calculate when to put each wine in the fridge
    func fridgeSchedule() -> [(wine: ConfirmedWine, putInTime: Date, takeOutTime: Date?)] {
        winesNeedingFridge.map { wine in
            let putInTime = dinnerDate.addingTimeInterval(-Double(wine.temperatureCategory.fridgeMinutes * 60))
            let takeOutTime: Date?
            if wine.temperatureCategory.takeOutMinutes > 0 {
                takeOutTime = dinnerDate.addingTimeInterval(-Double(wine.temperatureCategory.takeOutMinutes * 60))
            } else {
                takeOutTime = nil
            }
            return (wine, putInTime, takeOutTime)
        }.sorted { $0.putInTime < $1.putInTime }
    }
}
