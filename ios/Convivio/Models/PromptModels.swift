import Foundation

// MARK: - Prompt Identifier

/// Identifies different types of prompts used in the app
enum PromptIdentifier: String, CaseIterable {
    case menuGeneration = "menu_generation"
    case dishRegeneration = "dish_regeneration"
    case wineRegeneration = "wine_regeneration"
    case inviteGeneration = "invite_generation"
    case detailedMenu = "detailed_menu"
    case sommelierChat = "sommelier_chat"

    var displayName: String {
        switch self {
        case .menuGeneration: return "Generazione Menu"
        case .dishRegeneration: return "Rigenerazione Piatto"
        case .wineRegeneration: return "Rigenerazione Vino"
        case .inviteGeneration: return "Generazione Invito"
        case .detailedMenu: return "Menu Dettagliato"
        case .sommelierChat: return "Chat Sommelier"
        }
    }
}

// MARK: - Prompt Template

/// Represents a prompt template with system and user components
struct PromptTemplate {
    let identifier: PromptIdentifier
    let systemPrompt: String
    let userPrompt: String
}

// MARK: - Prompt Configuration

/// Configuration for a prompt that can be edited in debug mode
struct PromptConfiguration: Equatable {
    var systemPrompt: String
    var userPrompt: String

    private let originalSystemPrompt: String
    private let originalUserPrompt: String

    init(systemPrompt: String, userPrompt: String) {
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
        self.originalSystemPrompt = systemPrompt
        self.originalUserPrompt = userPrompt
    }

    /// Returns true if either prompt has been modified from the original
    var isModified: Bool {
        systemPrompt != originalSystemPrompt || userPrompt != originalUserPrompt
    }

    /// Resets both prompts to their original values
    mutating func resetToOriginal() {
        systemPrompt = originalSystemPrompt
        userPrompt = originalUserPrompt
    }

    /// Returns the combined prompt for API calls
    var combinedPrompt: String {
        if systemPrompt.isEmpty {
            return userPrompt
        }
        return """
        \(systemPrompt)

        \(userPrompt)
        """
    }

    // Custom Equatable implementation to compare only visible properties
    static func == (lhs: PromptConfiguration, rhs: PromptConfiguration) -> Bool {
        lhs.systemPrompt == rhs.systemPrompt && lhs.userPrompt == rhs.userPrompt
    }
}
