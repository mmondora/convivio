import Foundation
import SwiftData

// MARK: - Wine Matching Service

/// Service for matching wine suggestions to cellar wines
struct WineMatchingService {

    /// Result of matching a wine suggestion to cellar
    struct MatchResult {
        let suggestion: SommelierWineSuggestion
        let match: WineMatch?
        let alternatives: [WineMatch]
    }

    /// A matched wine from the cellar
    struct WineMatch {
        let wine: Wine
        let bottle: Bottle
        let matchScore: Double  // 0.0 to 1.0
        let matchReason: String

        var totalQuantity: Int {
            bottle.quantity
        }

        var location: String? {
            bottle.location
        }
    }

    /// Attempts to match a wine suggestion to wines in the cellar
    /// - Parameters:
    ///   - suggestion: The wine suggestion from the sommelier
    ///   - wines: All wines in the cellar
    ///   - bottles: All bottles in the cellar
    /// - Returns: MatchResult with the best match and alternatives
    static func match(
        suggestion: SommelierWineSuggestion,
        wines: [Wine],
        bottles: [Bottle]
    ) -> MatchResult {
        var matches: [WineMatch] = []

        // Build a map of wine to bottles
        let wineBottles = Dictionary(grouping: bottles.filter { $0.quantity > 0 }) { $0.wine }

        for (wine, wineBottlesList) in wineBottles {
            guard let wine = wine else { continue }
            guard let primaryBottle = wineBottlesList.first else { continue }

            let (score, reason) = calculateMatchScore(suggestion: suggestion, wine: wine)

            if score > 0.2 { // Minimum threshold for considering a match
                matches.append(WineMatch(
                    wine: wine,
                    bottle: primaryBottle,
                    matchScore: score,
                    matchReason: reason
                ))
            }
        }

        // Sort by match score descending
        matches.sort { $0.matchScore > $1.matchScore }

        // Best match is the first one with score > 0.6, alternatives are others
        let bestMatch = matches.first(where: { $0.matchScore >= 0.6 })
        let alternatives = matches.filter { match in
            // Don't include the best match in alternatives
            if let best = bestMatch, best.wine === match.wine {
                return false
            }
            return match.matchScore >= 0.3
        }.prefix(3)

        return MatchResult(
            suggestion: suggestion,
            match: bestMatch,
            alternatives: Array(alternatives)
        )
    }

    /// Calculate match score between a suggestion and a wine
    private static func calculateMatchScore(
        suggestion: SommelierWineSuggestion,
        wine: Wine
    ) -> (score: Double, reason: String) {
        var score = 0.0
        var reasons: [String] = []

        let suggestionNameLower = suggestion.wineName.lowercased()
        let wineNameLower = wine.name.lowercased()
        let producerLower = wine.producer?.lowercased() ?? ""

        // 1. Exact name match (highest priority)
        if wineNameLower == suggestionNameLower {
            score += 0.5
            reasons.append("Nome esatto")
        }
        // 2. Wine name contains suggestion name or vice versa
        else if wineNameLower.contains(suggestionNameLower) || suggestionNameLower.contains(wineNameLower) {
            score += 0.35
            reasons.append("Nome simile")
        }
        // 3. Partial word match
        else {
            let suggestionWords = Set(suggestionNameLower.components(separatedBy: CharacterSet.whitespaces).filter { $0.count > 2 })
            let wineWords = Set(wineNameLower.components(separatedBy: CharacterSet.whitespaces).filter { $0.count > 2 })
            let commonWords = suggestionWords.intersection(wineWords)
            if !commonWords.isEmpty {
                score += 0.2 * Double(commonWords.count) / Double(max(suggestionWords.count, 1))
                reasons.append("Parole comuni: \(commonWords.joined(separator: ", "))")
            }
        }

        // 4. Producer match
        if let suggestionProducer = suggestion.producer?.lowercased(), !suggestionProducer.isEmpty {
            if producerLower == suggestionProducer {
                score += 0.25
                reasons.append("Produttore esatto")
            } else if producerLower.contains(suggestionProducer) || suggestionProducer.contains(producerLower) {
                score += 0.15
                reasons.append("Produttore simile")
            }
        }

        // 5. Wine type match
        if let suggestionType = suggestion.wineType {
            if wine.type == suggestionType {
                score += 0.15
                reasons.append("Stesso tipo di vino")
            }
        } else {
            // Try to infer type from name
            let inferredType = inferWineType(from: suggestionNameLower)
            if let inferred = inferredType, wine.type == inferred {
                score += 0.1
                reasons.append("Tipo simile")
            }
        }

        // 6. Region match
        if let suggestionRegion = suggestion.region?.lowercased(),
           let wineRegion = wine.region?.lowercased() {
            if wineRegion == suggestionRegion || wineRegion.contains(suggestionRegion) || suggestionRegion.contains(wineRegion) {
                score += 0.1
                reasons.append("Stessa regione")
            }
        }

        // 7. Grape variety match (bonus)
        if let suggestionGrapes = suggestion.grapes, !suggestionGrapes.isEmpty {
            let wineGrapesLower = Set(wine.grapes.map { $0.lowercased() })
            let suggestionGrapesLower = Set(suggestionGrapes.map { $0.lowercased() })
            let commonGrapes = wineGrapesLower.intersection(suggestionGrapesLower)
            if !commonGrapes.isEmpty {
                score += 0.1
                reasons.append("Vitigno comune")
            }
        }

        // Cap at 1.0
        score = min(score, 1.0)

        let reason = reasons.isEmpty ? "Corrispondenza generica" : reasons.joined(separator: ", ")
        return (score, reason)
    }

    /// Infer wine type from name
    private static func inferWineType(from name: String) -> WineType? {
        let nameLower = name.lowercased()

        // Sparkling indicators
        if nameLower.contains("spumante") || nameLower.contains("prosecco") ||
           nameLower.contains("champagne") || nameLower.contains("franciacorta") ||
           nameLower.contains("brut") || nameLower.contains("metodo classico") {
            return .sparkling
        }

        // Rosé indicators
        if nameLower.contains("rosato") || nameLower.contains("rosé") ||
           nameLower.contains("cerasuolo") || nameLower.contains("chiaretto") {
            return .rose
        }

        // White wine indicators
        if nameLower.contains("bianco") || nameLower.contains("verdicchio") ||
           nameLower.contains("pinot grigio") || nameLower.contains("sauvignon blanc") ||
           nameLower.contains("chardonnay") || nameLower.contains("vermentino") ||
           nameLower.contains("trebbiano") || nameLower.contains("soave") ||
           nameLower.contains("gavi") || nameLower.contains("falanghina") ||
           nameLower.contains("friulano") || nameLower.contains("pecorino") ||
           nameLower.contains("ribolla") || nameLower.contains("gewürztraminer") ||
           nameLower.contains("riesling") || nameLower.contains("müller") {
            return .white
        }

        // Dessert wine indicators
        if nameLower.contains("passito") || nameLower.contains("moscato") ||
           nameLower.contains("vin santo") || nameLower.contains("sauternes") ||
           nameLower.contains("late harvest") || nameLower.contains("vendemmia tardiva") {
            return .dessert
        }

        // Fortified wine indicators
        if nameLower.contains("porto") || nameLower.contains("marsala") ||
           nameLower.contains("sherry") || nameLower.contains("madeira") {
            return .fortified
        }

        // Default to red for common red varieties
        if nameLower.contains("rosso") || nameLower.contains("barolo") ||
           nameLower.contains("brunello") || nameLower.contains("chianti") ||
           nameLower.contains("amarone") || nameLower.contains("barbaresco") ||
           nameLower.contains("nebbiolo") || nameLower.contains("sangiovese") ||
           nameLower.contains("montepulciano") || nameLower.contains("primitivo") ||
           nameLower.contains("nero d'avola") || nameLower.contains("aglianico") ||
           nameLower.contains("merlot") || nameLower.contains("cabernet") ||
           nameLower.contains("syrah") || nameLower.contains("pinot nero") {
            return .red
        }

        return nil
    }

    /// Find alternatives for a wine type when no direct match is found
    static func findAlternatives(
        for suggestion: SommelierWineSuggestion,
        wines: [Wine],
        bottles: [Bottle],
        limit: Int = 3
    ) -> [WineMatch] {
        var matches: [WineMatch] = []

        let wineBottles = Dictionary(grouping: bottles.filter { $0.quantity > 0 }) { $0.wine }

        // Determine target type
        let targetType = suggestion.wineType ?? inferWineType(from: suggestion.wineName.lowercased())

        for (wine, wineBottlesList) in wineBottles {
            guard let wine = wine else { continue }
            guard let primaryBottle = wineBottlesList.first else { continue }

            var score = 0.0
            var reasons: [String] = []

            // Type match
            if let target = targetType, wine.type == target {
                score += 0.4
                reasons.append("Stesso tipo")
            }

            // Region match
            if let suggestionRegion = suggestion.region?.lowercased(),
               let wineRegion = wine.region?.lowercased() {
                if wineRegion.contains(suggestionRegion) || suggestionRegion.contains(wineRegion) {
                    score += 0.3
                    reasons.append("Stessa regione")
                }
            }

            // Grape variety match
            if let suggestionGrapes = suggestion.grapes {
                let wineGrapesLower = Set(wine.grapes.map { $0.lowercased() })
                let suggestionGrapesLower = Set(suggestionGrapes.map { $0.lowercased() })
                if !wineGrapesLower.intersection(suggestionGrapesLower).isEmpty {
                    score += 0.3
                    reasons.append("Vitigno simile")
                }
            }

            if score > 0.3 {
                matches.append(WineMatch(
                    wine: wine,
                    bottle: primaryBottle,
                    matchScore: score,
                    matchReason: reasons.joined(separator: ", ")
                ))
            }
        }

        matches.sort { $0.matchScore > $1.matchScore }
        return Array(matches.prefix(limit))
    }
}

// MARK: - Wine Suggestion Model

/// Represents a wine suggested by the sommelier
struct SommelierWineSuggestion: Identifiable {
    var id: UUID = UUID()
    let wineName: String
    let producer: String?
    let wineType: WineType?
    let region: String?
    let grapes: [String]?
    let reason: String?  // Why this wine was suggested

    init(
        wineName: String,
        producer: String? = nil,
        wineType: WineType? = nil,
        region: String? = nil,
        grapes: [String]? = nil,
        reason: String? = nil
    ) {
        self.wineName = wineName
        self.producer = producer
        self.wineType = wineType
        self.region = region
        self.grapes = grapes
        self.reason = reason
    }

    var displayName: String {
        var parts: [String] = []
        if let producer = producer { parts.append(producer) }
        parts.append(wineName)
        return parts.joined(separator: " ")
    }
}

// Separate Codable wrapper for JSON parsing
private struct SommelierWineSuggestionDTO: Codable {
    let wineName: String
    let producer: String?
    let wineType: String?
    let region: String?
    let grapes: [String]?
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case wineName = "wine_name"
        case producer
        case wineType = "wine_type"
        case region
        case grapes
        case reason
    }

    func toSommelierWineSuggestion() -> SommelierWineSuggestion {
        let type: WineType? = wineType.flatMap { WineType(rawValue: $0.lowercased()) }
        return SommelierWineSuggestion(
            wineName: wineName,
            producer: producer,
            wineType: type,
            region: region,
            grapes: grapes,
            reason: reason
        )
    }
}

// MARK: - Sommelier Response Parser

/// Parses sommelier responses to extract wine suggestions
struct SommelierResponseParser {

    /// Structured response from sommelier with text and suggestions
    struct ParsedResponse {
        let text: String
        let suggestions: [SommelierWineSuggestion]
    }

    /// Parse a sommelier response that may contain wine suggestions
    /// The AI is prompted to add suggestions in a JSON block at the end
    static func parse(_ response: String) -> ParsedResponse {
        // Look for the wine suggestions JSON block
        // Format: [WINE_SUGGESTIONS]{"suggestions":[...]}[/WINE_SUGGESTIONS]
        let pattern = #"\[WINE_SUGGESTIONS\](.*?)\[/WINE_SUGGESTIONS\]"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: response, options: [], range: NSRange(response.startIndex..., in: response)),
              let jsonRange = Range(match.range(at: 1), in: response) else {
            // No structured suggestions found, return text as-is
            return ParsedResponse(text: response, suggestions: [])
        }

        let jsonString = String(response[jsonRange])
        let textOnly = response.replacingOccurrences(
            of: #"\[WINE_SUGGESTIONS\].*?\[/WINE_SUGGESTIONS\]"#,
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        // Parse the JSON
        guard let jsonData = jsonString.data(using: .utf8) else {
            return ParsedResponse(text: textOnly, suggestions: [])
        }

        do {
            let decoded = try JSONDecoder().decode(SuggestionsWrapperDTO.self, from: jsonData)
            let suggestions = decoded.suggestions.map { $0.toSommelierWineSuggestion() }
            return ParsedResponse(text: textOnly, suggestions: suggestions)
        } catch {
            print("Failed to parse wine suggestions: \(error)")
            return ParsedResponse(text: textOnly, suggestions: [])
        }
    }

    private struct SuggestionsWrapperDTO: Codable {
        let suggestions: [SommelierWineSuggestionDTO]
    }
}
