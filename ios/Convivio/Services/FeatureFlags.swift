import Foundation

// MARK: - Feature Flags

/// Central configuration for feature toggles
/// Toggle these flags to enable/disable features during development
enum FeatureFlags {

    // MARK: - CloudKit & Sync

    /// Enable CloudKit sync and iCloud features
    /// Set to `true` when Apple Developer Program is active
    /// Set to `false` to use local-only storage
    static let cloudKitEnabled = false

    /// Enable push notifications for collaboration events
    /// Requires Apple Developer Program
    static let pushNotificationsEnabled = false

    // MARK: - Collaboration

    /// Enable sharing and collaboration features
    /// Can work without CloudKit for UI development, but sharing won't function
    static let collaborationEnabled = true

    /// Enable collaborative menu planning (proposals, voting, comments)
    static let collaborativeMenuEnabled = true

    // MARK: - Debug

    /// Show debug information in UI
    static let showDebugInfo: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    /// Log CloudKit operations
    static let logCloudKitOperations: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()
}

// MARK: - Convenience Extensions

extension FeatureFlags {
    /// Check if full iCloud features are available
    static var iCloudFeaturesAvailable: Bool {
        cloudKitEnabled && pushNotificationsEnabled
    }

    /// Check if any collaboration feature is enabled
    static var anyCollaborationEnabled: Bool {
        collaborationEnabled || collaborativeMenuEnabled
    }
}
