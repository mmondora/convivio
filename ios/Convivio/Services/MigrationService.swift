import Foundation
import SwiftData

// MARK: - Migration Service

/// Handles migration from local-only SwiftData to CloudKit-enabled storage
@MainActor
class MigrationService: ObservableObject {
    static let shared = MigrationService()

    // MARK: - Published Properties

    @Published var migrationStatus: MigrationStatus = .notStarted
    @Published var migrationProgress: Double = 0.0
    @Published var migrationError: String?

    // MARK: - Private Properties

    private let migrationCompletedKey = "CloudKitMigrationCompleted"
    private let migrationVersionKey = "CloudKitMigrationVersion"
    private let currentMigrationVersion = 1

    // MARK: - Initialization

    private init() {
        checkMigrationStatus()
    }

    // MARK: - Public Methods

    /// Check if migration is needed
    var needsMigration: Bool {
        let completed = UserDefaults.standard.bool(forKey: migrationCompletedKey)
        let version = UserDefaults.standard.integer(forKey: migrationVersionKey)
        return !completed || version < currentMigrationVersion
    }

    /// Check current migration status
    func checkMigrationStatus() {
        if UserDefaults.standard.bool(forKey: migrationCompletedKey) {
            let version = UserDefaults.standard.integer(forKey: migrationVersionKey)
            if version >= currentMigrationVersion {
                migrationStatus = .completed
            } else {
                migrationStatus = .notStarted
            }
        } else {
            migrationStatus = .notStarted
        }
    }

    /// Migrate local data to CloudKit
    func migrateLocalDataToCloudKit(context: ModelContext) async throws {
        guard needsMigration else {
            print("Migration already completed")
            migrationStatus = .completed
            return
        }

        migrationStatus = .inProgress
        migrationProgress = 0.0
        migrationError = nil

        do {
            // Step 1: Create default cellar
            migrationProgress = 0.1
            let defaultCellar = try await createDefaultCellar(context: context)

            // Step 2: Associate existing wines with cellar
            migrationProgress = 0.3
            try await migrateWines(to: defaultCellar, context: context)

            // Step 3: Associate existing storage areas
            migrationProgress = 0.5
            try await migrateStorageAreas(to: defaultCellar, context: context)

            // Step 4: Associate existing dinners
            migrationProgress = 0.7
            try await migrateDinners(to: defaultCellar, context: context)

            // Step 5: Save changes
            migrationProgress = 0.9
            try context.save()

            // Mark migration as completed
            UserDefaults.standard.set(true, forKey: migrationCompletedKey)
            UserDefaults.standard.set(currentMigrationVersion, forKey: migrationVersionKey)

            migrationProgress = 1.0
            migrationStatus = .completed
            print("Migration completed successfully")

        } catch {
            migrationStatus = .failed
            migrationError = error.localizedDescription
            print("Migration failed: \(error)")
            throw error
        }
    }

    /// Reset migration status (for debugging)
    func resetMigration() {
        UserDefaults.standard.removeObject(forKey: migrationCompletedKey)
        UserDefaults.standard.removeObject(forKey: migrationVersionKey)
        migrationStatus = .notStarted
        migrationProgress = 0.0
        migrationError = nil
    }

    // MARK: - Private Methods

    private func createDefaultCellar(context: ModelContext) async throws -> Cellar {
        // Check if a cellar already exists
        let existingCellars = try context.fetch(FetchDescriptor<Cellar>())
        if let existing = existingCellars.first {
            print("Using existing cellar: \(existing.name)")
            return existing
        }

        // Create new default cellar
        let cellar = Cellar(name: "La Mia Cantina")

        // Set owner ID if available
        if let cloudKit = try? await CloudKitService.shared.getCurrentUserRecordID() {
            cellar.ownerId = cloudKit.recordName
        }

        context.insert(cellar)
        print("Created default cellar")
        return cellar
    }

    private func migrateWines(to cellar: Cellar, context: ModelContext) async throws {
        let wines = try context.fetch(FetchDescriptor<Wine>())
        var migratedCount = 0

        for wine in wines {
            if wine.cellar == nil {
                wine.cellar = cellar
                migratedCount += 1
            }
        }

        print("Migrated \(migratedCount) wines to cellar")
    }

    private func migrateStorageAreas(to cellar: Cellar, context: ModelContext) async throws {
        let storageAreas = try context.fetch(FetchDescriptor<StorageArea>())
        var migratedCount = 0

        for area in storageAreas {
            if area.cellar == nil {
                area.cellar = cellar
                migratedCount += 1
            }
        }

        print("Migrated \(migratedCount) storage areas to cellar")
    }

    private func migrateDinners(to cellar: Cellar, context: ModelContext) async throws {
        let dinners = try context.fetch(FetchDescriptor<DinnerEvent>())
        var migratedCount = 0

        for dinner in dinners {
            if dinner.cellar == nil {
                dinner.cellar = cellar
                migratedCount += 1
            }
        }

        print("Migrated \(migratedCount) dinners to cellar")
    }
}

// MARK: - Migration Progress View

import SwiftUI

struct MigrationProgressView: View {
    @ObservedObject var migrationService = MigrationService.shared

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: 60))
                .foregroundColor(.purple)

            // Title
            Text("Migrazione in corso")
                .font(.title2.bold())

            // Description
            Text("Stiamo preparando i tuoi dati per la sincronizzazione con iCloud...")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Progress
            VStack(spacing: 8) {
                ProgressView(value: migrationService.migrationProgress)
                    .progressViewStyle(.linear)

                Text("\(Int(migrationService.migrationProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 40)

            // Error message
            if let error = migrationService.migrationError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding()
    }
}

#Preview {
    MigrationProgressView()
}
