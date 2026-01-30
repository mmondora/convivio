import Foundation

// MARK: - OpenAI Model

/// Available OpenAI models with different capabilities and costs
enum OpenAIModel: String, CaseIterable {
    case gpt4o = "gpt-4o"           // Best quality, higher cost
    case gpt4oMini = "gpt-4o-mini"  // Faster, cheaper, good for simple tasks

    var displayName: String {
        switch self {
        case .gpt4o: return "GPT-4o (Alta qualità)"
        case .gpt4oMini: return "GPT-4o Mini (Veloce)"
        }
    }

    var maxTokens: Int {
        switch self {
        case .gpt4o: return 16000     // For complex tasks
        case .gpt4oMini: return 4000  // Sufficient for simple tasks
        }
    }

    var isExpensive: Bool {
        self == .gpt4o
    }
}

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

    /// Recommended model for this task type
    /// Complex tasks use gpt-4o, simple tasks use gpt-4o-mini
    var recommendedModel: OpenAIModel {
        switch self {
        case .menuGeneration:
            return .gpt4o          // Complex: full menu with pairings
        case .detailedMenu:
            return .gpt4o          // Complex: detailed recipes and timeline
        case .dishRegeneration:
            return .gpt4oMini      // Simple: single dish replacement
        case .wineRegeneration:
            return .gpt4oMini      // Simple: single wine suggestion
        case .inviteGeneration:
            return .gpt4oMini      // Simple: text generation
        case .sommelierChat:
            return .gpt4oMini      // Simple: conversational responses
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
