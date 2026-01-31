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
    static var confirm: String { "common.confirm".localized }
    static var retry: String { "common.retry".localized }
    static var details: String { "common.details".localized }
    static var create: String { "common.create".localized }
    static var generating: String { "common.generating".localized }
    static var people: String { "common.people".localized }
    static var name: String { "common.name".localized }
    static var type: String { "common.type".localized }
    static var country: String { "common.country".localized }
    static var alcohol: String { "common.alcohol".localized }
    static var value: String { "common.value".localized }
    static var history: String { "common.history".localized }
    static var none: String { "common.none".localized }

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
    static var noBottles: String { "cellar.no_bottles".localized }
    static var addFirstBottle: String { "cellar.add_first_bottle".localized }
    static var noMatchingWines: String { "cellar.no_matching".localized }
    static var vintages: String { "cellar.vintages".localized }
    static var sortBy: String { "cellar.sort_by".localized }
    static var configureAreas: String { "cellar.configure_areas".localized }
    static var view: String { "cellar.view".localized }
    static var list: String { "cellar.list".localized }
    static var markAsDrunk: String { "cellar.mark_drunk".localized }
    static var markAsDrunkConfirm: String { "cellar.mark_drunk_confirm".localized }
    static var addBottle: String { "cellar.add_bottle".localized }
    static var notAssigned: String { "cellar.not_assigned".localized }
    static var addRating: String { "cellar.add_rating".localized }
    static var noRatingYet: String { "cellar.no_rating_yet".localized }
    static var averageRating: String { "cellar.average_rating".localized }
    static var ratingCount: String { "cellar.rating".localized }
    static var ratingsCount: String { "cellar.ratings".localized }
    static var wouldBuyAgain: String { "cellar.would_buy_again".localized }

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
    static var scanLabel: String { "scan.scan_label".localized }
    static var scanLabelDesc: String { "scan.scan_label_desc".localized }
    static var analyzingLabel: String { "scan.analyzing".localized }
    static var detectedInfo: String { "scan.detected_info".localized }
    static var editAndSave: String { "scan.edit_save".localized }
    static var recognitionConfidence: String { "scan.confidence".localized }

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
    static var noPlannedMeals: String { "food.no_planned".localized }
    static var addDinnerToStart: String { "food.add_to_start".localized }
    static var convivioDetails: String { "food.convivio_details".localized }
    static var titlePlaceholder: String { "food.title_placeholder".localized }
    static var dateTime: String { "food.datetime".localized }
    static var dietaryRestrictions: String { "food.dietary_restrictions".localized }
    static var diet: String { "food.diet".localized }
    static var cuisineType: String { "food.cuisine_type".localized }
    static var cuisine: String { "food.cuisine".localized }
    static var menuNotes: String { "food.menu_notes".localized }
    static var menuNotesPlaceholder: String { "food.menu_notes_placeholder".localized }
    static var newConvivio: String { "food.new_convivio".localized }
    static var confirmDinner: String { "food.confirm_dinner".localized }
    static var dinnerConfirmed: String { "food.dinner_confirmed".localized }
    static var dinnerCompleted: String { "food.dinner_completed".localized }
    static var winesConfirmedNote: String { "food.wines_confirmed_note".localized }
    static var deleteDishConfirm: String { "food.delete_dish_confirm".localized }
    static var deleteWineConfirm: String { "food.delete_wine_confirm".localized }
    static var deleteWine: String { "food.delete_wine".localized }
    static var unloadBottles: String { "food.unload_bottles".localized }
    static var toComplete: String { "food.to_complete".localized }
    static var proposals: String { "food.proposals".localized }
    static var proposeADish: String { "food.propose_dish".localized }
    static var participantsProposals: String { "food.participants_proposals".localized }
    static var aiWillCreate: String { "food.ai_will_create".localized }
    static var configureApiKey: String { "food.configure_api".localized }
    static var etiquette: String { "food.etiquette".localized }
    static var confirmUnload: String { "food.confirm_unload".localized }
    static var openBottleUnload: String { "food.open_unload".localized }
    static var wineNotifications: String { "food.wine_notifications".localized }
    static var noScheduledNotifications: String { "food.no_notifications".localized }
    static var putInFridgeMinutes: String { "food.put_fridge_minutes".localized }
    static var takeOutMinutes: String { "food.take_out_minutes".localized }
    static var servingTemp: String { "food.serving_temp".localized }

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
    static var suggestions: String { "sommelier.suggestions".localized }
    static var goToWine: String { "sommelier.go_to_wine".localized }
    static var alternativesFromCellar: String { "sommelier.alternatives".localized }

    // MARK: - Quick Suggestions
    static var suggestFish: String { "quick.fish".localized }
    static var suggestChardonnay: String { "quick.chardonnay".localized }
    static var suggestBestWine: String { "quick.best_wine".localized }
    static var suggestRedWine: String { "quick.red_wine".localized }

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
        "common.confirm": "Conferma",
        "common.retry": "Riprova",
        "common.details": "Dettagli",
        "common.create": "Crea",
        "common.generating": "Generazione...",
        "common.people": "persone",
        "common.name": "Nome",
        "common.type": "Tipo",
        "common.country": "Paese",
        "common.alcohol": "Gradazione",
        "common.value": "Valore",
        "common.history": "Storico",
        "common.none": "Nessuno",

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
        "cellar.no_bottles": "Nessuna bottiglia",
        "cellar.add_first_bottle": "Aggiungi la tua prima bottiglia scansionando un'etichetta o manualmente",
        "cellar.no_matching": "Nessun vino corrisponde ai filtri selezionati",
        "cellar.vintages": "annate",
        "cellar.sort_by": "Ordina per",
        "cellar.configure_areas": "Configura Aree",
        "cellar.view": "Vista",
        "cellar.list": "Lista",
        "cellar.mark_drunk": "Segna come bevuta",
        "cellar.mark_drunk_confirm": "Vuoi segnare questa bottiglia come bevuta?",
        "cellar.add_bottle": "Aggiungi Bottiglia",
        "cellar.not_assigned": "Non assegnata",
        "cellar.add_rating": "Aggiungi valutazione",
        "cellar.no_rating_yet": "Non hai ancora valutato questo vino",
        "cellar.average_rating": "Valutazione media",
        "cellar.rating": "valutazione",
        "cellar.ratings": "valutazioni",
        "cellar.would_buy_again": "Lo ricomprerei",

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
        "scan.scan_label": "Scansiona un'etichetta",
        "scan.scan_label_desc": "Fotografa l'etichetta di una bottiglia per aggiungerla automaticamente alla cantina",
        "scan.analyzing": "Analizzando l'etichetta...",
        "scan.detected_info": "Informazioni Rilevate",
        "scan.edit_save": "Modifica e Salva",
        "scan.confidence": "Confidenza riconoscimento",

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
        "food.no_planned": "Nessun pasto pianificato",
        "food.add_to_start": "Aggiungi una cena o un pranzo per iniziare",
        "food.convivio_details": "Dettagli Convivio",
        "food.title_placeholder": "Titolo (es: Cena di compleanno)",
        "food.datetime": "Data e ora",
        "food.dietary_restrictions": "Particolarità alimentari",
        "food.diet": "Dieta",
        "food.cuisine_type": "Tipo di cucina",
        "food.cuisine": "Cucina",
        "food.menu_notes": "Note per il menu",
        "food.menu_notes_placeholder": "Es: Menu leggero, no piccante, piatti della tradizione...",
        "food.new_convivio": "Nuovo Convivio",
        "food.confirm_dinner": "Conferma Cena",
        "food.dinner_confirmed": "Cena confermata",
        "food.dinner_completed": "Cena completata",
        "food.wines_confirmed_note": "Vini confermati - conferma la cena per bloccare il menu",
        "food.delete_dish_confirm": "Vuoi eliminare questo piatto dal menu?",
        "food.delete_wine_confirm": "Vuoi eliminare questo vino dagli abbinamenti?",
        "food.delete_wine": "Elimina vino",
        "food.unload_bottles": "Scarico Bottiglie",
        "food.to_complete": "Da completare - scarica bottiglie",
        "food.proposals": "proposte",
        "food.propose_dish": "Proponi un piatto",
        "food.participants_proposals": "Proposte dei partecipanti",
        "food.ai_will_create": "L'AI creerà un menu personalizzato con ricette e abbinamenti vino dalla tua cantina",
        "food.configure_api": "Configura l'API key OpenAI in Profilo",
        "food.etiquette": "Galateo",
        "food.confirm_unload": "Conferma Scarico",
        "food.open_unload": "Apri Scarico Bottiglie",
        "food.wine_notifications": "Notifiche Vini",
        "food.no_notifications": "Nessuna notifica programmata",
        "food.put_fridge_minutes": "min prima - Metti in frigo",
        "food.take_out_minutes": "min prima - Togli dal frigo",
        "food.serving_temp": "Temperatura servizio",

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
        "sommelier.suggestions": "Suggerimenti",
        "sommelier.go_to_wine": "Vai alla scheda vino",
        "sommelier.alternatives": "Alternative dalla tua cantina:",

        // Quick Suggestions
        "quick.fish": "Cosa mi consigli per una cena di pesce?",
        "quick.chardonnay": "Ho uno Chardonnay, con cosa lo abbino?",
        "quick.best_wine": "Qual è il vino migliore nella mia cantina?",
        "quick.red_wine": "Suggeriscimi un vino rosso corposo",

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
        "common.confirm": "Confirm",
        "common.retry": "Retry",
        "common.details": "Details",
        "common.create": "Create",
        "common.generating": "Generating...",
        "common.people": "people",
        "common.name": "Name",
        "common.type": "Type",
        "common.country": "Country",
        "common.alcohol": "Alcohol",
        "common.value": "Value",
        "common.history": "History",
        "common.none": "None",

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
        "cellar.no_bottles": "No bottles",
        "cellar.add_first_bottle": "Add your first bottle by scanning a label or manually",
        "cellar.no_matching": "No wines match the selected filters",
        "cellar.vintages": "vintages",
        "cellar.sort_by": "Sort by",
        "cellar.configure_areas": "Configure Areas",
        "cellar.view": "View",
        "cellar.list": "List",
        "cellar.mark_drunk": "Mark as drunk",
        "cellar.mark_drunk_confirm": "Do you want to mark this bottle as drunk?",
        "cellar.add_bottle": "Add Bottle",
        "cellar.not_assigned": "Not assigned",
        "cellar.add_rating": "Add rating",
        "cellar.no_rating_yet": "You haven't rated this wine yet",
        "cellar.average_rating": "Average rating",
        "cellar.rating": "rating",
        "cellar.ratings": "ratings",
        "cellar.would_buy_again": "Would buy again",

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
        "scan.scan_label": "Scan a label",
        "scan.scan_label_desc": "Take a photo of a wine label to automatically add it to your cellar",
        "scan.analyzing": "Analyzing the label...",
        "scan.detected_info": "Detected Information",
        "scan.edit_save": "Edit and Save",
        "scan.confidence": "Recognition confidence",

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
        "food.no_planned": "No planned meals",
        "food.add_to_start": "Add a dinner or lunch to get started",
        "food.convivio_details": "Convivio Details",
        "food.title_placeholder": "Title (e.g., Birthday dinner)",
        "food.datetime": "Date and time",
        "food.dietary_restrictions": "Dietary restrictions",
        "food.diet": "Diet",
        "food.cuisine_type": "Cuisine type",
        "food.cuisine": "Cuisine",
        "food.menu_notes": "Menu notes",
        "food.menu_notes_placeholder": "E.g., Light menu, not spicy, traditional dishes...",
        "food.new_convivio": "New Convivio",
        "food.confirm_dinner": "Confirm Dinner",
        "food.dinner_confirmed": "Dinner confirmed",
        "food.dinner_completed": "Dinner completed",
        "food.wines_confirmed_note": "Wines confirmed - confirm dinner to lock the menu",
        "food.delete_dish_confirm": "Do you want to remove this dish from the menu?",
        "food.delete_wine_confirm": "Do you want to remove this wine from the pairings?",
        "food.delete_wine": "Delete wine",
        "food.unload_bottles": "Bottle Unload",
        "food.to_complete": "To complete - unload bottles",
        "food.proposals": "proposals",
        "food.propose_dish": "Propose a dish",
        "food.participants_proposals": "Participants' proposals",
        "food.ai_will_create": "AI will create a personalized menu with recipes and wine pairings from your cellar",
        "food.configure_api": "Configure OpenAI API key in Profile",
        "food.etiquette": "Etiquette",
        "food.confirm_unload": "Confirm Unload",
        "food.open_unload": "Open Bottle Unload",
        "food.wine_notifications": "Wine Notifications",
        "food.no_notifications": "No scheduled notifications",
        "food.put_fridge_minutes": "min before - Put in fridge",
        "food.take_out_minutes": "min before - Take out of fridge",
        "food.serving_temp": "Serving temperature",

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
        "sommelier.suggestions": "Suggestions",
        "sommelier.go_to_wine": "Go to wine card",
        "sommelier.alternatives": "Alternatives from your cellar:",

        // Quick Suggestions
        "quick.fish": "What do you suggest for a seafood dinner?",
        "quick.chardonnay": "I have a Chardonnay, what to pair with?",
        "quick.best_wine": "What's the best wine in my cellar?",
        "quick.red_wine": "Suggest a full-bodied red wine",

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
        "common.confirm": "Bestätigen",
        "common.retry": "Erneut versuchen",
        "common.details": "Details",
        "common.create": "Erstellen",
        "common.generating": "Wird generiert...",
        "common.people": "Personen",
        "common.name": "Name",
        "common.type": "Typ",
        "common.country": "Land",
        "common.alcohol": "Alkohol",
        "common.value": "Wert",
        "common.history": "Verlauf",
        "common.none": "Keine",

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
        "cellar.no_bottles": "Keine Flaschen",
        "cellar.add_first_bottle": "Fügen Sie Ihre erste Flasche hinzu, indem Sie ein Etikett scannen oder manuell eingeben",
        "cellar.no_matching": "Keine Weine entsprechen den ausgewählten Filtern",
        "cellar.vintages": "Jahrgänge",
        "cellar.sort_by": "Sortieren nach",
        "cellar.configure_areas": "Bereiche konfigurieren",
        "cellar.view": "Ansicht",
        "cellar.list": "Liste",
        "cellar.mark_drunk": "Als getrunken markieren",
        "cellar.mark_drunk_confirm": "Möchten Sie diese Flasche als getrunken markieren?",
        "cellar.add_bottle": "Flasche hinzufügen",
        "cellar.not_assigned": "Nicht zugewiesen",
        "cellar.add_rating": "Bewertung hinzufügen",
        "cellar.no_rating_yet": "Sie haben diesen Wein noch nicht bewertet",
        "cellar.average_rating": "Durchschnittliche Bewertung",
        "cellar.rating": "Bewertung",
        "cellar.ratings": "Bewertungen",
        "cellar.would_buy_again": "Würde wieder kaufen",

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
        "scan.scan_label": "Ein Etikett scannen",
        "scan.scan_label_desc": "Fotografieren Sie ein Weinetikett, um es automatisch zum Keller hinzuzufügen",
        "scan.analyzing": "Etikett wird analysiert...",
        "scan.detected_info": "Erkannte Informationen",
        "scan.edit_save": "Bearbeiten und Speichern",
        "scan.confidence": "Erkennungssicherheit",

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
        "food.no_planned": "Keine geplanten Mahlzeiten",
        "food.add_to_start": "Fügen Sie ein Abendessen hinzu, um zu beginnen",
        "food.convivio_details": "Convivio-Details",
        "food.title_placeholder": "Titel (z.B. Geburtstagsessen)",
        "food.datetime": "Datum und Uhrzeit",
        "food.dietary_restrictions": "Ernährungseinschränkungen",
        "food.diet": "Diät",
        "food.cuisine_type": "Küchenart",
        "food.cuisine": "Küche",
        "food.menu_notes": "Menü-Notizen",
        "food.menu_notes_placeholder": "Z.B. Leichtes Menü, nicht scharf, traditionelle Gerichte...",
        "food.new_convivio": "Neues Convivio",
        "food.confirm_dinner": "Abendessen bestätigen",
        "food.dinner_confirmed": "Abendessen bestätigt",
        "food.dinner_completed": "Abendessen abgeschlossen",
        "food.wines_confirmed_note": "Weine bestätigt - Abendessen bestätigen, um das Menü zu sperren",
        "food.delete_dish_confirm": "Möchten Sie dieses Gericht aus dem Menü entfernen?",
        "food.delete_wine_confirm": "Möchten Sie diesen Wein aus den Empfehlungen entfernen?",
        "food.delete_wine": "Wein löschen",
        "food.unload_bottles": "Flaschen entladen",
        "food.to_complete": "Abzuschließen - Flaschen entladen",
        "food.proposals": "Vorschläge",
        "food.propose_dish": "Ein Gericht vorschlagen",
        "food.participants_proposals": "Vorschläge der Teilnehmer",
        "food.ai_will_create": "KI erstellt ein personalisiertes Menü mit Rezepten und Weinempfehlungen aus Ihrem Keller",
        "food.configure_api": "OpenAI API-Schlüssel im Profil konfigurieren",
        "food.etiquette": "Etikette",
        "food.confirm_unload": "Entladen bestätigen",
        "food.open_unload": "Flaschenentladung öffnen",
        "food.wine_notifications": "Weinbenachrichtigungen",
        "food.no_notifications": "Keine geplanten Benachrichtigungen",
        "food.put_fridge_minutes": "Min. vorher - In den Kühlschrank stellen",
        "food.take_out_minutes": "Min. vorher - Aus dem Kühlschrank nehmen",
        "food.serving_temp": "Serviertemperatur",

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
        "sommelier.suggestions": "Vorschläge",
        "sommelier.go_to_wine": "Zur Weinkarte",
        "sommelier.alternatives": "Alternativen aus Ihrem Keller:",

        // Quick Suggestions
        "quick.fish": "Was empfehlen Sie für ein Fischessen?",
        "quick.chardonnay": "Ich habe einen Chardonnay, wozu passt er?",
        "quick.best_wine": "Was ist der beste Wein in meinem Keller?",
        "quick.red_wine": "Empfehlen Sie mir einen vollmundigen Rotwein",

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
        "common.confirm": "Confirmer",
        "common.retry": "Réessayer",
        "common.details": "Détails",
        "common.create": "Créer",
        "common.generating": "Génération...",
        "common.people": "personnes",
        "common.name": "Nom",
        "common.type": "Type",
        "common.country": "Pays",
        "common.alcohol": "Alcool",
        "common.value": "Valeur",
        "common.history": "Historique",
        "common.none": "Aucun",

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
        "cellar.no_bottles": "Aucune bouteille",
        "cellar.add_first_bottle": "Ajoutez votre première bouteille en scannant une étiquette ou manuellement",
        "cellar.no_matching": "Aucun vin ne correspond aux filtres sélectionnés",
        "cellar.vintages": "millésimes",
        "cellar.sort_by": "Trier par",
        "cellar.configure_areas": "Configurer les zones",
        "cellar.view": "Vue",
        "cellar.list": "Liste",
        "cellar.mark_drunk": "Marquer comme bu",
        "cellar.mark_drunk_confirm": "Voulez-vous marquer cette bouteille comme bue?",
        "cellar.add_bottle": "Ajouter une bouteille",
        "cellar.not_assigned": "Non attribué",
        "cellar.add_rating": "Ajouter une évaluation",
        "cellar.no_rating_yet": "Vous n'avez pas encore évalué ce vin",
        "cellar.average_rating": "Évaluation moyenne",
        "cellar.rating": "évaluation",
        "cellar.ratings": "évaluations",
        "cellar.would_buy_again": "Achèterais à nouveau",

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
        "scan.scan_label": "Scanner une étiquette",
        "scan.scan_label_desc": "Photographiez une étiquette de vin pour l'ajouter automatiquement à votre cave",
        "scan.analyzing": "Analyse de l'étiquette...",
        "scan.detected_info": "Informations détectées",
        "scan.edit_save": "Modifier et enregistrer",
        "scan.confidence": "Confiance de reconnaissance",

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
        "food.no_planned": "Aucun repas prévu",
        "food.add_to_start": "Ajoutez un dîner pour commencer",
        "food.convivio_details": "Détails Convivio",
        "food.title_placeholder": "Titre (ex: Dîner d'anniversaire)",
        "food.datetime": "Date et heure",
        "food.dietary_restrictions": "Restrictions alimentaires",
        "food.diet": "Régime",
        "food.cuisine_type": "Type de cuisine",
        "food.cuisine": "Cuisine",
        "food.menu_notes": "Notes du menu",
        "food.menu_notes_placeholder": "Ex: Menu léger, pas épicé, plats traditionnels...",
        "food.new_convivio": "Nouveau Convivio",
        "food.confirm_dinner": "Confirmer le dîner",
        "food.dinner_confirmed": "Dîner confirmé",
        "food.dinner_completed": "Dîner terminé",
        "food.wines_confirmed_note": "Vins confirmés - confirmez le dîner pour verrouiller le menu",
        "food.delete_dish_confirm": "Voulez-vous supprimer ce plat du menu?",
        "food.delete_wine_confirm": "Voulez-vous supprimer ce vin des accords?",
        "food.delete_wine": "Supprimer le vin",
        "food.unload_bottles": "Décharger les bouteilles",
        "food.to_complete": "À terminer - décharger les bouteilles",
        "food.proposals": "propositions",
        "food.propose_dish": "Proposer un plat",
        "food.participants_proposals": "Propositions des participants",
        "food.ai_will_create": "L'IA créera un menu personnalisé avec des recettes et des accords de votre cave",
        "food.configure_api": "Configurez la clé API OpenAI dans le Profil",
        "food.etiquette": "Étiquette",
        "food.confirm_unload": "Confirmer le déchargement",
        "food.open_unload": "Ouvrir le déchargement",
        "food.wine_notifications": "Notifications de vin",
        "food.no_notifications": "Aucune notification programmée",
        "food.put_fridge_minutes": "min avant - Mettre au frigo",
        "food.take_out_minutes": "min avant - Sortir du frigo",
        "food.serving_temp": "Température de service",

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
        "sommelier.suggestions": "Suggestions",
        "sommelier.go_to_wine": "Voir la fiche du vin",
        "sommelier.alternatives": "Alternatives de votre cave:",

        // Quick Suggestions
        "quick.fish": "Que me conseillez-vous pour un dîner de fruits de mer?",
        "quick.chardonnay": "J'ai un Chardonnay, avec quoi l'accorder?",
        "quick.best_wine": "Quel est le meilleur vin de ma cave?",
        "quick.red_wine": "Suggérez-moi un vin rouge corsé",

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
