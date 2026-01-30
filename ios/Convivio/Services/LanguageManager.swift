import Foundation
import SwiftUI

// MARK: - Supported Languages

enum AppLanguage: String, CaseIterable, Identifiable {
    case italian = "it"
    case english = "en"
    case german = "de"
    case french = "fr"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .italian: return "Italiano"
        case .english: return "English"
        case .german: return "Deutsch"
        case .french: return "Français"
        }
    }

    var flag: String {
        switch self {
        case .italian: return "🇮🇹"
        case .english: return "🇬🇧"
        case .german: return "🇩🇪"
        case .french: return "🇫🇷"
        }
    }

    static func fromDeviceLanguage() -> AppLanguage {
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        let languageCode = String(preferredLanguage.prefix(2))
        return AppLanguage(rawValue: languageCode) ?? .english
    }
}

// MARK: - Localization Keys

enum L10n {
    // MARK: - Tab Bar
    static var cellar: String { "tab.cellar".localized }
    static var scan: String { "tab.scan".localized }
    static var convivio: String { "Convivio" } // Never translated
    static var sommelier: String { "tab.sommelier".localized }
    static var profile: String { "tab.profile".localized }

    // MARK: - Common
    static var cancel: String { "common.cancel".localized }
    static var save: String { "common.save".localized }
    static var delete: String { "common.delete".localized }
    static var edit: String { "common.edit".localized }
    static var add: String { "common.add".localized }
    static var done: String { "common.done".localized }
    static var close: String { "common.close".localized }
    static var search: String { "common.search".localized }
    static var loading: String { "common.loading".localized }
    static var error: String { "common.error".localized }
    static var success: String { "common.success".localized }
    static var bottles: String { "common.bottles".localized }
    static var wine: String { "common.wine".localized }
    static var wines: String { "common.wines".localized }

    // MARK: - Cellar
    static var myCellar: String { "cellar.title".localized }
    static var addWine: String { "cellar.add_wine".localized }
    static var emptyWelcome: String { "cellar.empty.title".localized }
    static var emptyDescription: String { "cellar.empty.description".localized }
    static var lowStock: String { "cellar.low_stock".localized }
    static var allWines: String { "cellar.all_wines".localized }
    static var byLocation: String { "cellar.by_location".localized }
    static var noLocation: String { "cellar.no_location".localized }
    static var quantity: String { "cellar.quantity".localized }
    static var vintage: String { "cellar.vintage".localized }
    static var producer: String { "cellar.producer".localized }
    static var region: String { "cellar.region".localized }
    static var grapes: String { "cellar.grapes".localized }
    static var notes: String { "cellar.notes".localized }
    static var location: String { "cellar.location".localized }
    static var position: String { "cellar.position".localized }

    // MARK: - Wine Types
    static var redWine: String { "wine.type.red".localized }
    static var whiteWine: String { "wine.type.white".localized }
    static var roseWine: String { "wine.type.rose".localized }
    static var sparklingWine: String { "wine.type.sparkling".localized }
    static var dessertWine: String { "wine.type.dessert".localized }
    static var fortifiedWine: String { "wine.type.fortified".localized }

    // MARK: - Scan
    static var scanTitle: String { "scan.title".localized }
    static var scanInstructions: String { "scan.instructions".localized }
    static var scanProcessing: String { "scan.processing".localized }
    static var takePhoto: String { "scan.take_photo".localized }
    static var choosePhoto: String { "scan.choose_photo".localized }

    // MARK: - Food/Dinner
    static var dinners: String { "food.dinners".localized }
    static var newDinner: String { "food.new_dinner".localized }
    static var editDinner: String { "food.edit_dinner".localized }
    static var dinnerTitle: String { "food.dinner_title".localized }
    static var date: String { "food.date".localized }
    static var guests: String { "food.guests".localized }
    static var occasion: String { "food.occasion".localized }
    static var menu: String { "food.menu".localized }
    static var generateMenu: String { "food.generate_menu".localized }
    static var regenerateMenu: String { "food.regenerate_menu".localized }
    static var winePairings: String { "food.wine_pairings".localized }
    static var fromCellar: String { "food.from_cellar".localized }
    static var toBuy: String { "food.to_buy".localized }
    static var regenerateDish: String { "food.regenerate_dish".localized }
    static var deleteDish: String { "food.delete_dish".localized }
    static var confirmWines: String { "food.confirm_wines".localized }
    static var generateInvite: String { "food.generate_invite".localized }
    static var shareInvite: String { "food.share_invite".localized }

    // MARK: - Courses
    static var appetizers: String { "course.appetizers".localized }
    static var firstCourses: String { "course.first".localized }
    static var mainCourses: String { "course.main".localized }
    static var sideDishes: String { "course.sides".localized }
    static var desserts: String { "course.desserts".localized }

    // MARK: - Occasions
    static var birthday: String { "occasion.birthday".localized }
    static var anniversary: String { "occasion.anniversary".localized }
    static var romanticDinner: String { "occasion.romantic".localized }
    static var businessDinner: String { "occasion.business".localized }
    static var party: String { "occasion.party".localized }
    static var friendsDinner: String { "occasion.friends".localized }

    // MARK: - Sommelier
    static var askSommelier: String { "sommelier.ask".localized }
    static var sommelierPlaceholder: String { "sommelier.placeholder".localized }
    static var inCellar: String { "sommelier.in_cellar".localized }
    static var suggestedWines: String { "sommelier.suggested_wines".localized }

    // MARK: - Profile
    static var settings: String { "profile.settings".localized }
    static var language: String { "profile.language".localized }
    static var apiKey: String { "profile.api_key".localized }
    static var apiKeyPlaceholder: String { "profile.api_key_placeholder".localized }
    static var tastePreferences: String { "profile.taste_preferences".localized }
    static var storageManagement: String { "profile.storage_management".localized }
    static var storageAreas: String { "profile.storage_areas".localized }
    static var about: String { "profile.about".localized }
    static var version: String { "profile.version".localized }
    static var clearData: String { "profile.clear_data".localized }

    // MARK: - Storage
    static var addArea: String { "storage.add_area".localized }
    static var editArea: String { "storage.edit_area".localized }
    static var areaName: String { "storage.area_name".localized }
    static var addContainer: String { "storage.add_container".localized }
    static var editContainer: String { "storage.edit_container".localized }
    static var containerName: String { "storage.container_name".localized }
    static var capacity: String { "storage.capacity".localized }
    static var noAreasConfigured: String { "storage.no_areas".localized }
    static var noAreasDescription: String { "storage.no_areas_desc".localized }

    // MARK: - Onboarding
    static var welcomeTitle: String { "onboarding.welcome_title".localized }
    static var welcomeSubtitle: String { "onboarding.welcome_subtitle".localized }
    static var apiKeyRequired: String { "onboarding.api_key_required".localized }
    static var apiKeyInstructions: String { "onboarding.api_key_instructions".localized }
    static var getStarted: String { "onboarding.get_started".localized }
    static var enterApiKey: String { "onboarding.enter_api_key".localized }
    static var skipForNow: String { "onboarding.skip".localized }

    // MARK: - Ratings
    static var rating: String { "rating.title".localized }
    static var quickRating: String { "rating.quick".localized }
    static var detailedRating: String { "rating.detailed".localized }
    static var myRatings: String { "rating.my_ratings".localized }

    // MARK: - Notifications
    static var putInFridge: String { "notification.put_in_fridge".localized }
    static var takeOutOfFridge: String { "notification.take_out_fridge".localized }
    static var dinnerReminder: String { "notification.dinner_reminder".localized }

    // MARK: - Errors
    static var networkError: String { "error.network".localized }
    static var apiError: String { "error.api".localized }
    static var parseError: String { "error.parse".localized }
    static var unknownError: String { "error.unknown".localized }
}

// MARK: - Language Manager

@MainActor
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
        }
    }

    private init() {
        if let savedLanguage = UserDefaults.standard.string(forKey: "app_language"),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            self.currentLanguage = AppLanguage.fromDeviceLanguage()
        }
    }

    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
    }

    func string(for key: String) -> String {
        let strings = Self.strings[currentLanguage] ?? Self.strings[.english]!
        return strings[key] ?? key
    }

    // MARK: - Localization Strings (nonisolated for thread-safe access)

    nonisolated static let strings: [AppLanguage: [String: String]] = [
        .italian: italianStrings,
        .english: englishStrings,
        .german: germanStrings,
        .french: frenchStrings
    ]

    // MARK: - Italian
    nonisolated static let italianStrings: [String: String] = [
        // Tab Bar
        "tab.cellar": "Cantina",
        "tab.scan": "Scansiona",
        "tab.sommelier": "Sommelier",
        "tab.profile": "Profilo",

        // Common
        "common.cancel": "Annulla",
        "common.save": "Salva",
        "common.delete": "Elimina",
        "common.edit": "Modifica",
        "common.add": "Aggiungi",
        "common.done": "Fatto",
        "common.close": "Chiudi",
        "common.search": "Cerca",
        "common.loading": "Caricamento...",
        "common.error": "Errore",
        "common.success": "Successo",
        "common.bottles": "bottiglie",
        "common.wine": "vino",
        "common.wines": "vini",

        // Cellar
        "cellar.title": "La mia Cantina",
        "cellar.add_wine": "Aggiungi vino",
        "cellar.empty.title": "Benvenuto in Convivio!",
        "cellar.empty.description": "Inizia a scansionare le tue etichette per costruire la tua cantina virtuale.",
        "cellar.low_stock": "Scorta bassa",
        "cellar.all_wines": "Tutti i vini",
        "cellar.by_location": "Per posizione",
        "cellar.no_location": "Senza posizione",
        "cellar.quantity": "Quantità",
        "cellar.vintage": "Annata",
        "cellar.producer": "Produttore",
        "cellar.region": "Regione",
        "cellar.grapes": "Vitigni",
        "cellar.notes": "Note",
        "cellar.location": "Posizione",
        "cellar.position": "Posizione nel contenitore",

        // Wine Types
        "wine.type.red": "Rosso",
        "wine.type.white": "Bianco",
        "wine.type.rose": "Rosato",
        "wine.type.sparkling": "Spumante",
        "wine.type.dessert": "Dolce",
        "wine.type.fortified": "Fortificato",

        // Scan
        "scan.title": "Scansiona Etichetta",
        "scan.instructions": "Inquadra l'etichetta del vino per aggiungerlo alla tua cantina",
        "scan.processing": "Elaborazione in corso...",
        "scan.take_photo": "Scatta foto",
        "scan.choose_photo": "Scegli dalla libreria",

        // Food/Dinner
        "food.dinners": "Le mie cene",
        "food.new_dinner": "Nuova cena",
        "food.edit_dinner": "Modifica cena",
        "food.dinner_title": "Titolo",
        "food.date": "Data",
        "food.guests": "Ospiti",
        "food.occasion": "Occasione",
        "food.menu": "Menu",
        "food.generate_menu": "Genera menu",
        "food.regenerate_menu": "Rigenera menu",
        "food.wine_pairings": "Abbinamenti vino",
        "food.from_cellar": "Dalla cantina",
        "food.to_buy": "Da acquistare",
        "food.regenerate_dish": "Rigenera piatto",
        "food.delete_dish": "Elimina piatto",
        "food.confirm_wines": "Conferma vini",
        "food.generate_invite": "Genera invito",
        "food.share_invite": "Condividi invito",

        // Courses
        "course.appetizers": "Antipasti",
        "course.first": "Primi",
        "course.main": "Secondi",
        "course.sides": "Contorni",
        "course.desserts": "Dolci",

        // Occasions
        "occasion.birthday": "Compleanno",
        "occasion.anniversary": "Anniversario",
        "occasion.romantic": "Cena romantica",
        "occasion.business": "Cena di lavoro",
        "occasion.party": "Festa",
        "occasion.friends": "Cena tra amici",

        // Sommelier
        "sommelier.ask": "Chiedi al sommelier",
        "sommelier.placeholder": "Chiedi un consiglio...",
        "sommelier.in_cellar": "In cantina",
        "sommelier.suggested_wines": "Vini suggeriti",

        // Profile
        "profile.settings": "Impostazioni",
        "profile.language": "Lingua",
        "profile.api_key": "API Key OpenAI",
        "profile.api_key_placeholder": "sk-...",
        "profile.taste_preferences": "Preferenze di gusto",
        "profile.storage_management": "Gestione cantina",
        "profile.storage_areas": "Aree di stoccaggio",
        "profile.about": "Informazioni",
        "profile.version": "Versione",
        "profile.clear_data": "Cancella dati",

        // Storage
        "storage.add_area": "Aggiungi area",
        "storage.edit_area": "Modifica area",
        "storage.area_name": "Nome area",
        "storage.add_container": "Aggiungi contenitore",
        "storage.edit_container": "Modifica contenitore",
        "storage.container_name": "Nome contenitore",
        "storage.capacity": "Capacità",
        "storage.no_areas": "Nessuna area configurata",
        "storage.no_areas_desc": "Aggiungi aree di stoccaggio come Cantina, Cucina, ecc.",

        // Onboarding
        "onboarding.welcome_title": "Benvenuto in Convivio",
        "onboarding.welcome_subtitle": "Il tuo sommelier personale AI",
        "onboarding.api_key_required": "API Key richiesta",
        "onboarding.api_key_instructions": "Per utilizzare le funzionalità AI, inserisci la tua API Key di OpenAI. Puoi ottenerla su platform.openai.com",
        "onboarding.get_started": "Inizia",
        "onboarding.enter_api_key": "Inserisci API Key",
        "onboarding.skip": "Salta per ora",

        // Ratings
        "rating.title": "Valutazione",
        "rating.quick": "Valutazione rapida",
        "rating.detailed": "Scheda AIS",
        "rating.my_ratings": "Le mie valutazioni",

        // Notifications
        "notification.put_in_fridge": "Metti in frigo",
        "notification.take_out_fridge": "Togli dal frigo",
        "notification.dinner_reminder": "Promemoria cena",

        // Errors
        "error.network": "Errore di rete",
        "error.api": "Errore API",
        "error.parse": "Errore elaborazione dati",
        "error.unknown": "Errore sconosciuto"
    ]

    // MARK: - English
    nonisolated static let englishStrings: [String: String] = [
        // Tab Bar
        "tab.cellar": "Cellar",
        "tab.scan": "Scan",
        "tab.sommelier": "Sommelier",
        "tab.profile": "Profile",

        // Common
        "common.cancel": "Cancel",
        "common.save": "Save",
        "common.delete": "Delete",
        "common.edit": "Edit",
        "common.add": "Add",
        "common.done": "Done",
        "common.close": "Close",
        "common.search": "Search",
        "common.loading": "Loading...",
        "common.error": "Error",
        "common.success": "Success",
        "common.bottles": "bottles",
        "common.wine": "wine",
        "common.wines": "wines",

        // Cellar
        "cellar.title": "My Cellar",
        "cellar.add_wine": "Add wine",
        "cellar.empty.title": "Welcome to Convivio!",
        "cellar.empty.description": "Start scanning your wine labels to build your virtual cellar.",
        "cellar.low_stock": "Low stock",
        "cellar.all_wines": "All wines",
        "cellar.by_location": "By location",
        "cellar.no_location": "No location",
        "cellar.quantity": "Quantity",
        "cellar.vintage": "Vintage",
        "cellar.producer": "Producer",
        "cellar.region": "Region",
        "cellar.grapes": "Grapes",
        "cellar.notes": "Notes",
        "cellar.location": "Location",
        "cellar.position": "Position in container",

        // Wine Types
        "wine.type.red": "Red",
        "wine.type.white": "White",
        "wine.type.rose": "Rosé",
        "wine.type.sparkling": "Sparkling",
        "wine.type.dessert": "Dessert",
        "wine.type.fortified": "Fortified",

        // Scan
        "scan.title": "Scan Label",
        "scan.instructions": "Point at the wine label to add it to your cellar",
        "scan.processing": "Processing...",
        "scan.take_photo": "Take photo",
        "scan.choose_photo": "Choose from library",

        // Food/Dinner
        "food.dinners": "My dinners",
        "food.new_dinner": "New dinner",
        "food.edit_dinner": "Edit dinner",
        "food.dinner_title": "Title",
        "food.date": "Date",
        "food.guests": "Guests",
        "food.occasion": "Occasion",
        "food.menu": "Menu",
        "food.generate_menu": "Generate menu",
        "food.regenerate_menu": "Regenerate menu",
        "food.wine_pairings": "Wine pairings",
        "food.from_cellar": "From cellar",
        "food.to_buy": "To buy",
        "food.regenerate_dish": "Regenerate dish",
        "food.delete_dish": "Delete dish",
        "food.confirm_wines": "Confirm wines",
        "food.generate_invite": "Generate invite",
        "food.share_invite": "Share invite",

        // Courses
        "course.appetizers": "Appetizers",
        "course.first": "First courses",
        "course.main": "Main courses",
        "course.sides": "Side dishes",
        "course.desserts": "Desserts",

        // Occasions
        "occasion.birthday": "Birthday",
        "occasion.anniversary": "Anniversary",
        "occasion.romantic": "Romantic dinner",
        "occasion.business": "Business dinner",
        "occasion.party": "Party",
        "occasion.friends": "Dinner with friends",

        // Sommelier
        "sommelier.ask": "Ask the sommelier",
        "sommelier.placeholder": "Ask for advice...",
        "sommelier.in_cellar": "In cellar",
        "sommelier.suggested_wines": "Suggested wines",

        // Profile
        "profile.settings": "Settings",
        "profile.language": "Language",
        "profile.api_key": "OpenAI API Key",
        "profile.api_key_placeholder": "sk-...",
        "profile.taste_preferences": "Taste preferences",
        "profile.storage_management": "Storage management",
        "profile.storage_areas": "Storage areas",
        "profile.about": "About",
        "profile.version": "Version",
        "profile.clear_data": "Clear data",

        // Storage
        "storage.add_area": "Add area",
        "storage.edit_area": "Edit area",
        "storage.area_name": "Area name",
        "storage.add_container": "Add container",
        "storage.edit_container": "Edit container",
        "storage.container_name": "Container name",
        "storage.capacity": "Capacity",
        "storage.no_areas": "No areas configured",
        "storage.no_areas_desc": "Add storage areas like Cellar, Kitchen, etc.",

        // Onboarding
        "onboarding.welcome_title": "Welcome to Convivio",
        "onboarding.welcome_subtitle": "Your personal AI sommelier",
        "onboarding.api_key_required": "API Key required",
        "onboarding.api_key_instructions": "To use AI features, enter your OpenAI API Key. Get one at platform.openai.com",
        "onboarding.get_started": "Get Started",
        "onboarding.enter_api_key": "Enter API Key",
        "onboarding.skip": "Skip for now",

        // Ratings
        "rating.title": "Rating",
        "rating.quick": "Quick rating",
        "rating.detailed": "AIS form",
        "rating.my_ratings": "My ratings",

        // Notifications
        "notification.put_in_fridge": "Put in fridge",
        "notification.take_out_fridge": "Take out of fridge",
        "notification.dinner_reminder": "Dinner reminder",

        // Errors
        "error.network": "Network error",
        "error.api": "API error",
        "error.parse": "Data parsing error",
        "error.unknown": "Unknown error"
    ]

    // MARK: - German
    nonisolated static let germanStrings: [String: String] = [
        // Tab Bar
        "tab.cellar": "Weinkeller",
        "tab.scan": "Scannen",
        "tab.sommelier": "Sommelier",
        "tab.profile": "Profil",

        // Common
        "common.cancel": "Abbrechen",
        "common.save": "Speichern",
        "common.delete": "Löschen",
        "common.edit": "Bearbeiten",
        "common.add": "Hinzufügen",
        "common.done": "Fertig",
        "common.close": "Schließen",
        "common.search": "Suchen",
        "common.loading": "Laden...",
        "common.error": "Fehler",
        "common.success": "Erfolg",
        "common.bottles": "Flaschen",
        "common.wine": "Wein",
        "common.wines": "Weine",

        // Cellar
        "cellar.title": "Mein Weinkeller",
        "cellar.add_wine": "Wein hinzufügen",
        "cellar.empty.title": "Willkommen bei Convivio!",
        "cellar.empty.description": "Scannen Sie Ihre Weinetiketten, um Ihren virtuellen Weinkeller aufzubauen.",
        "cellar.low_stock": "Niedriger Bestand",
        "cellar.all_wines": "Alle Weine",
        "cellar.by_location": "Nach Standort",
        "cellar.no_location": "Kein Standort",
        "cellar.quantity": "Menge",
        "cellar.vintage": "Jahrgang",
        "cellar.producer": "Erzeuger",
        "cellar.region": "Region",
        "cellar.grapes": "Rebsorten",
        "cellar.notes": "Notizen",
        "cellar.location": "Standort",
        "cellar.position": "Position im Behälter",

        // Wine Types
        "wine.type.red": "Rotwein",
        "wine.type.white": "Weißwein",
        "wine.type.rose": "Rosé",
        "wine.type.sparkling": "Schaumwein",
        "wine.type.dessert": "Dessertwein",
        "wine.type.fortified": "Likörwein",

        // Scan
        "scan.title": "Etikett scannen",
        "scan.instructions": "Richten Sie die Kamera auf das Weinetikett",
        "scan.processing": "Verarbeitung...",
        "scan.take_photo": "Foto aufnehmen",
        "scan.choose_photo": "Aus Bibliothek wählen",

        // Food/Dinner
        "food.dinners": "Meine Abendessen",
        "food.new_dinner": "Neues Abendessen",
        "food.edit_dinner": "Abendessen bearbeiten",
        "food.dinner_title": "Titel",
        "food.date": "Datum",
        "food.guests": "Gäste",
        "food.occasion": "Anlass",
        "food.menu": "Menü",
        "food.generate_menu": "Menü erstellen",
        "food.regenerate_menu": "Menü neu erstellen",
        "food.wine_pairings": "Weinempfehlungen",
        "food.from_cellar": "Aus dem Keller",
        "food.to_buy": "Zu kaufen",
        "food.regenerate_dish": "Gericht neu erstellen",
        "food.delete_dish": "Gericht löschen",
        "food.confirm_wines": "Weine bestätigen",
        "food.generate_invite": "Einladung erstellen",
        "food.share_invite": "Einladung teilen",

        // Courses
        "course.appetizers": "Vorspeisen",
        "course.first": "Erste Gänge",
        "course.main": "Hauptgerichte",
        "course.sides": "Beilagen",
        "course.desserts": "Desserts",

        // Occasions
        "occasion.birthday": "Geburtstag",
        "occasion.anniversary": "Jubiläum",
        "occasion.romantic": "Romantisches Abendessen",
        "occasion.business": "Geschäftsessen",
        "occasion.party": "Party",
        "occasion.friends": "Abendessen mit Freunden",

        // Sommelier
        "sommelier.ask": "Sommelier fragen",
        "sommelier.placeholder": "Fragen Sie nach einem Rat...",
        "sommelier.in_cellar": "Im Keller",
        "sommelier.suggested_wines": "Empfohlene Weine",

        // Profile
        "profile.settings": "Einstellungen",
        "profile.language": "Sprache",
        "profile.api_key": "OpenAI API-Schlüssel",
        "profile.api_key_placeholder": "sk-...",
        "profile.taste_preferences": "Geschmacksvorlieben",
        "profile.storage_management": "Lagerverwaltung",
        "profile.storage_areas": "Lagerbereiche",
        "profile.about": "Über",
        "profile.version": "Version",
        "profile.clear_data": "Daten löschen",

        // Storage
        "storage.add_area": "Bereich hinzufügen",
        "storage.edit_area": "Bereich bearbeiten",
        "storage.area_name": "Bereichsname",
        "storage.add_container": "Behälter hinzufügen",
        "storage.edit_container": "Behälter bearbeiten",
        "storage.container_name": "Behältername",
        "storage.capacity": "Kapazität",
        "storage.no_areas": "Keine Bereiche konfiguriert",
        "storage.no_areas_desc": "Fügen Sie Lagerbereiche wie Keller, Küche usw. hinzu.",

        // Onboarding
        "onboarding.welcome_title": "Willkommen bei Convivio",
        "onboarding.welcome_subtitle": "Ihr persönlicher KI-Sommelier",
        "onboarding.api_key_required": "API-Schlüssel erforderlich",
        "onboarding.api_key_instructions": "Um KI-Funktionen zu nutzen, geben Sie Ihren OpenAI API-Schlüssel ein. Sie erhalten ihn auf platform.openai.com",
        "onboarding.get_started": "Loslegen",
        "onboarding.enter_api_key": "API-Schlüssel eingeben",
        "onboarding.skip": "Vorerst überspringen",

        // Ratings
        "rating.title": "Bewertung",
        "rating.quick": "Schnellbewertung",
        "rating.detailed": "AIS-Formular",
        "rating.my_ratings": "Meine Bewertungen",

        // Notifications
        "notification.put_in_fridge": "In den Kühlschrank stellen",
        "notification.take_out_fridge": "Aus dem Kühlschrank nehmen",
        "notification.dinner_reminder": "Abendessen-Erinnerung",

        // Errors
        "error.network": "Netzwerkfehler",
        "error.api": "API-Fehler",
        "error.parse": "Datenverarbeitungsfehler",
        "error.unknown": "Unbekannter Fehler"
    ]

    // MARK: - French
    nonisolated static let frenchStrings: [String: String] = [
        // Tab Bar
        "tab.cellar": "Cave",
        "tab.scan": "Scanner",
        "tab.sommelier": "Sommelier",
        "tab.profile": "Profil",

        // Common
        "common.cancel": "Annuler",
        "common.save": "Enregistrer",
        "common.delete": "Supprimer",
        "common.edit": "Modifier",
        "common.add": "Ajouter",
        "common.done": "Terminé",
        "common.close": "Fermer",
        "common.search": "Rechercher",
        "common.loading": "Chargement...",
        "common.error": "Erreur",
        "common.success": "Succès",
        "common.bottles": "bouteilles",
        "common.wine": "vin",
        "common.wines": "vins",

        // Cellar
        "cellar.title": "Ma Cave",
        "cellar.add_wine": "Ajouter un vin",
        "cellar.empty.title": "Bienvenue sur Convivio!",
        "cellar.empty.description": "Commencez à scanner vos étiquettes de vin pour construire votre cave virtuelle.",
        "cellar.low_stock": "Stock faible",
        "cellar.all_wines": "Tous les vins",
        "cellar.by_location": "Par emplacement",
        "cellar.no_location": "Sans emplacement",
        "cellar.quantity": "Quantité",
        "cellar.vintage": "Millésime",
        "cellar.producer": "Producteur",
        "cellar.region": "Région",
        "cellar.grapes": "Cépages",
        "cellar.notes": "Notes",
        "cellar.location": "Emplacement",
        "cellar.position": "Position dans le contenant",

        // Wine Types
        "wine.type.red": "Rouge",
        "wine.type.white": "Blanc",
        "wine.type.rose": "Rosé",
        "wine.type.sparkling": "Pétillant",
        "wine.type.dessert": "Dessert",
        "wine.type.fortified": "Fortifié",

        // Scan
        "scan.title": "Scanner l'étiquette",
        "scan.instructions": "Pointez vers l'étiquette du vin pour l'ajouter à votre cave",
        "scan.processing": "Traitement en cours...",
        "scan.take_photo": "Prendre une photo",
        "scan.choose_photo": "Choisir de la bibliothèque",

        // Food/Dinner
        "food.dinners": "Mes dîners",
        "food.new_dinner": "Nouveau dîner",
        "food.edit_dinner": "Modifier le dîner",
        "food.dinner_title": "Titre",
        "food.date": "Date",
        "food.guests": "Invités",
        "food.occasion": "Occasion",
        "food.menu": "Menu",
        "food.generate_menu": "Générer le menu",
        "food.regenerate_menu": "Régénérer le menu",
        "food.wine_pairings": "Accords mets-vins",
        "food.from_cellar": "De la cave",
        "food.to_buy": "À acheter",
        "food.regenerate_dish": "Régénérer le plat",
        "food.delete_dish": "Supprimer le plat",
        "food.confirm_wines": "Confirmer les vins",
        "food.generate_invite": "Générer l'invitation",
        "food.share_invite": "Partager l'invitation",

        // Courses
        "course.appetizers": "Entrées",
        "course.first": "Premiers plats",
        "course.main": "Plats principaux",
        "course.sides": "Accompagnements",
        "course.desserts": "Desserts",

        // Occasions
        "occasion.birthday": "Anniversaire",
        "occasion.anniversary": "Anniversaire de mariage",
        "occasion.romantic": "Dîner romantique",
        "occasion.business": "Dîner d'affaires",
        "occasion.party": "Fête",
        "occasion.friends": "Dîner entre amis",

        // Sommelier
        "sommelier.ask": "Demander au sommelier",
        "sommelier.placeholder": "Demandez un conseil...",
        "sommelier.in_cellar": "En cave",
        "sommelier.suggested_wines": "Vins suggérés",

        // Profile
        "profile.settings": "Paramètres",
        "profile.language": "Langue",
        "profile.api_key": "Clé API OpenAI",
        "profile.api_key_placeholder": "sk-...",
        "profile.taste_preferences": "Préférences de goût",
        "profile.storage_management": "Gestion du stockage",
        "profile.storage_areas": "Zones de stockage",
        "profile.about": "À propos",
        "profile.version": "Version",
        "profile.clear_data": "Effacer les données",

        // Storage
        "storage.add_area": "Ajouter une zone",
        "storage.edit_area": "Modifier la zone",
        "storage.area_name": "Nom de la zone",
        "storage.add_container": "Ajouter un contenant",
        "storage.edit_container": "Modifier le contenant",
        "storage.container_name": "Nom du contenant",
        "storage.capacity": "Capacité",
        "storage.no_areas": "Aucune zone configurée",
        "storage.no_areas_desc": "Ajoutez des zones de stockage comme Cave, Cuisine, etc.",

        // Onboarding
        "onboarding.welcome_title": "Bienvenue sur Convivio",
        "onboarding.welcome_subtitle": "Votre sommelier IA personnel",
        "onboarding.api_key_required": "Clé API requise",
        "onboarding.api_key_instructions": "Pour utiliser les fonctionnalités IA, entrez votre clé API OpenAI. Obtenez-la sur platform.openai.com",
        "onboarding.get_started": "Commencer",
        "onboarding.enter_api_key": "Entrer la clé API",
        "onboarding.skip": "Passer pour l'instant",

        // Ratings
        "rating.title": "Évaluation",
        "rating.quick": "Évaluation rapide",
        "rating.detailed": "Fiche AIS",
        "rating.my_ratings": "Mes évaluations",

        // Notifications
        "notification.put_in_fridge": "Mettre au frigo",
        "notification.take_out_fridge": "Sortir du frigo",
        "notification.dinner_reminder": "Rappel de dîner",

        // Errors
        "error.network": "Erreur réseau",
        "error.api": "Erreur API",
        "error.parse": "Erreur de traitement des données",
        "error.unknown": "Erreur inconnue"
    ]
}

// MARK: - String Extension

extension String {
    var localized: String {
        // Use UserDefaults directly for thread-safe access
        let languageCode = UserDefaults.standard.string(forKey: "app_language")
            ?? String(Locale.preferredLanguages.first?.prefix(2) ?? "en")
        let language = AppLanguage(rawValue: languageCode) ?? .english
        let strings = LanguageManager.strings[language] ?? LanguageManager.strings[.english]!
        return strings[self] ?? self
    }
}
