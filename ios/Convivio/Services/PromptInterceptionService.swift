import Foundation
import SwiftUI

// MARK: - Prompt Interception Service

/// Service that intercepts prompts in debug mode to allow editing before sending to API
@MainActor
class PromptInterceptionService: ObservableObject {
    static let shared = PromptInterceptionService()

    @Published var isShowingEditor = false
    @Published var currentPrompt: PromptConfiguration?
    @Published var currentIdentifier: PromptIdentifier?

    private var continuation: CheckedContinuation<PromptConfiguration?, Never>?
    private var originalPrompt: PromptConfiguration?

    private init() {}

    // MARK: - Public Methods

    /// Intercepts a prompt before API call. In debug mode, shows editor and waits for user input.
    /// - Parameters:
    ///   - identifier: The type of prompt being intercepted
    ///   - systemPrompt: The system prompt (can be empty)
    ///   - userPrompt: The user prompt
    ///   - debugEnabled: Whether debug mode is enabled
    /// - Returns: The (potentially modified) prompt configuration, or nil if cancelled
    func interceptPrompt(
        identifier: PromptIdentifier,
        systemPrompt: String,
        userPrompt: String,
        debugEnabled: Bool
    ) async -> PromptConfiguration? {
        // If debug is disabled, return the prompt immediately
        guard debugEnabled else {
            return PromptConfiguration(systemPrompt: systemPrompt, userPrompt: userPrompt)
        }

        // Show editor and wait for user input
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            self.currentIdentifier = identifier
            let config = PromptConfiguration(systemPrompt: systemPrompt, userPrompt: userPrompt)
            self.currentPrompt = config
            self.originalPrompt = config
            self.isShowingEditor = true
        }
    }

    /// Called when user submits the edited prompt
    func submitPrompt(_ config: PromptConfiguration) {
        isShowingEditor = false
        continuation?.resume(returning: config)
        cleanup()
    }

    /// Called when user cancels prompt editing
    func cancelPrompt() {
        isShowingEditor = false
        continuation?.resume(returning: nil)
        cleanup()
    }

    /// Resets the current prompt to the original values
    func resetToDefault() {
        if let original = originalPrompt {
            currentPrompt = original
        }
    }

    // MARK: - Private Methods

    private func cleanup() {
        continuation = nil
        currentPrompt = nil
        currentIdentifier = nil
        originalPrompt = nil
    }
}

// MARK: - Cancellation Error

enum PromptInterceptionError: LocalizedError {
    case cancelled

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Operazione annullata dall'utente"
        }
    }
}
