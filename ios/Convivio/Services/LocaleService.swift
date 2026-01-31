import Foundation

// MARK: - Locale Service

/// Service for managing user locale settings and cuisine adaptation
@MainActor
class LocaleService: ObservableObject {
    static let shared = LocaleService()

    private init() {}

    // MARK: - Supported Languages

    struct SupportedLanguage: Identifiable, Hashable {
        let id: String  // Language code
        let displayName: String
        let nativeName: String
        let promptName: String  // Name to use in prompts

        static let all: [SupportedLanguage] = [
            SupportedLanguage(id: "it", displayName: "Italiano", nativeName: "Italiano", promptName: "italiano"),
            SupportedLanguage(id: "en", displayName: "English", nativeName: "English", promptName: "English"),
            SupportedLanguage(id: "fr", displayName: "Français", nativeName: "Français", promptName: "français"),
            SupportedLanguage(id: "de", displayName: "Deutsch", nativeName: "Deutsch", promptName: "Deutsch"),
            SupportedLanguage(id: "es", displayName: "Español", nativeName: "Español", promptName: "español"),
            SupportedLanguage(id: "pt", displayName: "Português", nativeName: "Português", promptName: "português"),
            SupportedLanguage(id: "ja", displayName: "日本語", nativeName: "日本語", promptName: "日本語"),
            SupportedLanguage(id: "zh", displayName: "中文", nativeName: "中文", promptName: "中文")
        ]

        static func find(byId id: String) -> SupportedLanguage? {
            all.first { $0.id == id }
        }
    }

    // MARK: - Supported Countries

    struct SupportedCountry: Identifiable, Hashable {
        let id: String  // ISO country code
        let displayName: String
        let nativeName: String
        let cuisineName: String  // Name of the country's cuisine

        static let all: [SupportedCountry] = [
            // Europe
            SupportedCountry(id: "IT", displayName: "Italia", nativeName: "Italia", cuisineName: "italiana"),
            SupportedCountry(id: "FR", displayName: "Francia", nativeName: "France", cuisineName: "francese"),
            SupportedCountry(id: "ES", displayName: "Spagna", nativeName: "España", cuisineName: "spagnola"),
            SupportedCountry(id: "DE", displayName: "Germania", nativeName: "Deutschland", cuisineName: "tedesca"),
            SupportedCountry(id: "GB", displayName: "Regno Unito", nativeName: "United Kingdom", cuisineName: "britannica"),
            SupportedCountry(id: "PT", displayName: "Portogallo", nativeName: "Portugal", cuisineName: "portoghese"),
            SupportedCountry(id: "GR", displayName: "Grecia", nativeName: "Ελλάδα", cuisineName: "greca"),
            SupportedCountry(id: "CH", displayName: "Svizzera", nativeName: "Schweiz", cuisineName: "svizzera"),
            SupportedCountry(id: "AT", displayName: "Austria", nativeName: "Österreich", cuisineName: "austriaca"),
            SupportedCountry(id: "BE", displayName: "Belgio", nativeName: "België", cuisineName: "belga"),
            SupportedCountry(id: "NL", displayName: "Paesi Bassi", nativeName: "Nederland", cuisineName: "olandese"),

            // Americas
            SupportedCountry(id: "US", displayName: "Stati Uniti", nativeName: "United States", cuisineName: "americana"),
            SupportedCountry(id: "CA", displayName: "Canada", nativeName: "Canada", cuisineName: "canadese"),
            SupportedCountry(id: "MX", displayName: "Messico", nativeName: "México", cuisineName: "messicana"),
            SupportedCountry(id: "BR", displayName: "Brasile", nativeName: "Brasil", cuisineName: "brasiliana"),
            SupportedCountry(id: "AR", displayName: "Argentina", nativeName: "Argentina", cuisineName: "argentina"),
            SupportedCountry(id: "PE", displayName: "Peru", nativeName: "Perú", cuisineName: "peruviana"),

            // Asia
            SupportedCountry(id: "JP", displayName: "Giappone", nativeName: "日本", cuisineName: "giapponese"),
            SupportedCountry(id: "CN", displayName: "Cina", nativeName: "中国", cuisineName: "cinese"),
            SupportedCountry(id: "KR", displayName: "Corea del Sud", nativeName: "대한민국", cuisineName: "coreana"),
            SupportedCountry(id: "IN", displayName: "India", nativeName: "भारत", cuisineName: "indiana"),
            SupportedCountry(id: "TH", displayName: "Thailandia", nativeName: "ประเทศไทย", cuisineName: "thailandese"),
            SupportedCountry(id: "VN", displayName: "Vietnam", nativeName: "Việt Nam", cuisineName: "vietnamita"),

            // Oceania
            SupportedCountry(id: "AU", displayName: "Australia", nativeName: "Australia", cuisineName: "australiana"),
            SupportedCountry(id: "NZ", displayName: "Nuova Zelanda", nativeName: "New Zealand", cuisineName: "neozelandese"),

            // Middle East & Africa
            SupportedCountry(id: "TR", displayName: "Turchia", nativeName: "Türkiye", cuisineName: "turca"),
            SupportedCountry(id: "MA", displayName: "Marocco", nativeName: "المغرب", cuisineName: "marocchina"),
            SupportedCountry(id: "LB", displayName: "Libano", nativeName: "لبنان", cuisineName: "libanese"),
            SupportedCountry(id: "IL", displayName: "Israele", nativeName: "ישראל", cuisineName: "israeliana"),
            SupportedCountry(id: "ZA", displayName: "Sudafrica", nativeName: "South Africa", cuisineName: "sudafricana")
        ]

        static func find(byId id: String) -> SupportedCountry? {
            all.first { $0.id == id }
        }
    }

    // MARK: - Cuisine Types

    struct CuisineType: Identifiable, Hashable {
        let id: String
        let displayName: String
        let countryCode: String?  // If associated with a specific country

        static let international: [CuisineType] = [
            CuisineType(id: "traditional", displayName: "Cucina tradizionale", countryCode: nil),
            CuisineType(id: "mediterranean", displayName: "Cucina mediterranea", countryCode: nil),
            CuisineType(id: "fusion", displayName: "Cucina fusion", countryCode: nil),
            CuisineType(id: "vegetarian", displayName: "Cucina vegetariana", countryCode: nil),
            CuisineType(id: "vegan", displayName: "Cucina vegana", countryCode: nil),
            CuisineType(id: "seafood", displayName: "Cucina di mare", countryCode: nil),
            CuisineType(id: "grill", displayName: "Grill & BBQ", countryCode: nil),
            // Country-specific cuisines
            CuisineType(id: "italian", displayName: "Cucina italiana", countryCode: "IT"),
            CuisineType(id: "french", displayName: "Cucina francese", countryCode: "FR"),
            CuisineType(id: "spanish", displayName: "Cucina spagnola", countryCode: "ES"),
            CuisineType(id: "japanese", displayName: "Cucina giapponese", countryCode: "JP"),
            CuisineType(id: "chinese", displayName: "Cucina cinese", countryCode: "CN"),
            CuisineType(id: "indian", displayName: "Cucina indiana", countryCode: "IN"),
            CuisineType(id: "thai", displayName: "Cucina thailandese", countryCode: "TH"),
            CuisineType(id: "mexican", displayName: "Cucina messicana", countryCode: "MX"),
            CuisineType(id: "greek", displayName: "Cucina greca", countryCode: "GR"),
            CuisineType(id: "moroccan", displayName: "Cucina marocchina", countryCode: "MA"),
            CuisineType(id: "lebanese", displayName: "Cucina libanese", countryCode: "LB"),
            CuisineType(id: "korean", displayName: "Cucina coreana", countryCode: "KR"),
            CuisineType(id: "vietnamese", displayName: "Cucina vietnamita", countryCode: "VN"),
            CuisineType(id: "peruvian", displayName: "Cucina peruviana", countryCode: "PE"),
            CuisineType(id: "brazilian", displayName: "Cucina brasiliana", countryCode: "BR"),
            CuisineType(id: "american", displayName: "Cucina americana", countryCode: "US"),
            CuisineType(id: "british", displayName: "Cucina britannica", countryCode: "GB"),
            CuisineType(id: "german", displayName: "Cucina tedesca", countryCode: "DE"),
            CuisineType(id: "portuguese", displayName: "Cucina portoghese", countryCode: "PT"),
            CuisineType(id: "turkish", displayName: "Cucina turca", countryCode: "TR"),
            CuisineType(id: "australian", displayName: "Cucina australiana", countryCode: "AU")
        ]
    }

    // MARK: - Cuisine Adaptation

    /// Get adapted cuisine types for a user's country
    /// If the cuisine matches the user's country, it becomes "Cucina tradizionale"
    func getAdaptedCuisineTypes(forUserCountry countryCode: String?) -> [CuisineType] {
        var result: [CuisineType] = []

        // Always add "Cucina tradizionale" first
        result.append(CuisineType(id: "traditional", displayName: "Cucina tradizionale", countryCode: nil))

        // Add non-country-specific cuisines
        result.append(contentsOf: CuisineType.international.filter { $0.countryCode == nil && $0.id != "traditional" })

        // Add country-specific cuisines (excluding user's own country)
        let foreignCuisines = CuisineType.international
            .filter { $0.countryCode != nil && $0.countryCode != countryCode }
            .sorted { $0.displayName < $1.displayName }

        result.append(contentsOf: foreignCuisines)

        return result
    }

    /// Adapt a cuisine type name based on user's country
    /// Returns "Cucina tradizionale" if the cuisine matches the user's country
    func adaptCuisineName(_ cuisineType: CuisineType, forUserCountry countryCode: String?) -> String {
        if let cuisineCountry = cuisineType.countryCode,
           let userCountry = countryCode,
           cuisineCountry == userCountry {
            return "Cucina tradizionale"
        }
        return cuisineType.displayName
    }

    /// Get the cuisine type for prompts, adapting for user's location
    func getCuisineForPrompts(_ cuisineId: String, userCountry: String?) -> String {
        guard let cuisine = CuisineType.international.first(where: { $0.id == cuisineId }) else {
            return cuisineId
        }

        return adaptCuisineName(cuisine, forUserCountry: userCountry)
    }

    // MARK: - Device Locale Detection

    /// Get the device's current language code
    var deviceLanguageCode: String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }

    /// Get the device's current country code
    var deviceCountryCode: String? {
        Locale.current.region?.identifier
    }

    /// Get suggested country based on device locale
    func suggestedCountry() -> SupportedCountry? {
        guard let countryCode = deviceCountryCode else { return nil }
        return SupportedCountry.find(byId: countryCode)
    }

    /// Get suggested language based on device locale
    func suggestedLanguage() -> SupportedLanguage? {
        SupportedLanguage.find(byId: deviceLanguageCode)
    }
}

// MARK: - Locale Context

/// Context object containing all locale-related information for prompts
struct LocaleContext {
    let language: String      // Language name for prompts (e.g., "italiano")
    let languageCode: String  // ISO code (e.g., "it")
    let city: String?         // User's city
    let country: String?      // Country name (e.g., "Italia")
    let countryCode: String?  // ISO code (e.g., "IT")

    /// Location string for prompts (city, country or just country)
    var locationForPrompts: String {
        if let city = city, let country = country {
            return "\(city), \(country)"
        }
        return country ?? "non specificato"
    }

    /// Create from AppSettings
    static func from(settings: AppSettings?) -> LocaleContext {
        let languageCode = settings?.effectiveLanguage ?? "en"
        let language = LocaleService.SupportedLanguage.find(byId: languageCode)?.promptName ?? "English"

        let countryCode = settings?.userCountry
        let country = countryCode.flatMap { LocaleService.SupportedCountry.find(byId: $0)?.displayName }

        return LocaleContext(
            language: language,
            languageCode: languageCode,
            city: settings?.userCity,
            country: country,
            countryCode: countryCode
        )
    }
}
