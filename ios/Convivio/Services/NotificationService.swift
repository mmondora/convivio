import Foundation
import UserNotifications

// MARK: - Notification Service

@MainActor
class NotificationService {
    static let shared = NotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Permission

    /// Request notification permission from the user
    func requestPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Error requesting notification permission: \(error)")
            return false
        }
    }

    /// Check current notification permission status
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Wine Temperature Notifications

    /// Schedule all wine temperature notifications for a dinner
    /// Returns tuple with updated wines and post-dinner notification ID
    func scheduleWineNotifications(
        for dinner: DinnerEvent,
        wines: [ConfirmedWine]
    ) async throws -> (wines: [ConfirmedWine], postDinnerNotificationId: String?) {
        // Check permission first
        let status = await checkPermissionStatus()
        guard status == .authorized else {
            throw NotificationError.notAuthorized
        }

        var updatedWines: [ConfirmedWine] = []

        for var wine in wines {
            // Cancel any existing notifications for this wine
            if let putInId = wine.putInFridgeNotificationId {
                notificationCenter.removePendingNotificationRequests(withIdentifiers: [putInId])
            }
            if let takeOutId = wine.takeOutNotificationId {
                notificationCenter.removePendingNotificationRequests(withIdentifiers: [takeOutId])
            }

            // Only schedule if wine needs refrigeration
            if wine.temperatureCategory.needsFridge {
                // Schedule "put in fridge" notification
                do {
                    let putInId = try await schedulePutInFridgeNotification(
                        wine: wine,
                        dinnerDate: dinner.date,
                        dinnerTitle: dinner.title
                    )
                    wine.putInFridgeNotificationId = putInId
                } catch NotificationError.dateInPast {
                    // Ignore if time already passed
                }

                // Schedule "take out" notification if needed
                if wine.temperatureCategory.takeOutMinutes > 0 {
                    do {
                        let takeOutId = try await scheduleTakeOutNotification(
                            wine: wine,
                            dinnerDate: dinner.date,
                            dinnerTitle: dinner.title
                        )
                        wine.takeOutNotificationId = takeOutId
                    } catch NotificationError.dateInPast {
                        // Ignore if time already passed
                    }
                }
            }

            updatedWines.append(wine)
        }

        // Schedule post-dinner notification for bottle unload reminder
        var postDinnerNotificationId: String? = nil
        if !wines.filter({ $0.isFromCellar }).isEmpty {
            do {
                postDinnerNotificationId = try await schedulePostDinnerNotification(for: dinner)
            } catch NotificationError.dateInPast {
                // Ignore if dinner is already past
            }
        }

        return (updatedWines, postDinnerNotificationId)
    }

    /// Cancel all notifications for a dinner (including post-dinner reminder)
    func cancelNotifications(for dinner: DinnerEvent) async {
        let wines = dinner.confirmedWines
        var identifiers: [String] = []

        for wine in wines {
            if let putInId = wine.putInFridgeNotificationId {
                identifiers.append(putInId)
            }
            if let takeOutId = wine.takeOutNotificationId {
                identifiers.append(takeOutId)
            }
        }

        // Also cancel post-dinner notification if scheduled
        if let postDinnerId = dinner.postDinnerNotificationId {
            identifiers.append(postDinnerId)
        }

        if !identifiers.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    // MARK: - Post-Dinner Bottle Unload Notification

    /// Schedule a notification 4 hours after dinner to remind user to unload bottles
    /// Returns the notification ID
    func schedulePostDinnerNotification(for dinner: DinnerEvent) async throws -> String {
        // Check permission first
        let status = await checkPermissionStatus()
        guard status == .authorized else {
            throw NotificationError.notAuthorized
        }

        // Cancel existing post-dinner notification if any
        if let existingId = dinner.postDinnerNotificationId {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: [existingId])
        }

        let notificationId = "postDinner-\(dinner.title.hashValue)-\(dinner.date.timeIntervalSince1970)"

        // Schedule 4 hours after dinner time
        let notificationDate = dinner.date.addingTimeInterval(4 * 60 * 60)

        // Don't schedule if the time has already passed
        guard notificationDate > Date() else {
            throw NotificationError.dateInPast
        }

        let content = UNMutableNotificationContent()
        content.title = "Com'è andata la cena?"
        content.body = "Conferma le bottiglie consumate per aggiornare la cantina"
        content.sound = .default
        content.categoryIdentifier = "BOTTLE_UNLOAD"
        content.userInfo = [
            "dinnerTitle": dinner.title,
            "action": "unloadBottles"
        ]

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: notificationDate
            ),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(request)
        return notificationId
    }

    /// Cancel post-dinner notification for a specific dinner
    func cancelPostDinnerNotification(for dinner: DinnerEvent) {
        if let notificationId = dinner.postDinnerNotificationId {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationId])
        }
    }

    /// Cancel all notifications for a specific wine
    func cancelNotifications(for wine: ConfirmedWine) {
        var identifiers: [String] = []
        if let putInId = wine.putInFridgeNotificationId {
            identifiers.append(putInId)
        }
        if let takeOutId = wine.takeOutNotificationId {
            identifiers.append(takeOutId)
        }
        if !identifiers.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    // MARK: - Private Scheduling Methods

    private func schedulePutInFridgeNotification(
        wine: ConfirmedWine,
        dinnerDate: Date,
        dinnerTitle: String
    ) async throws -> String {
        let notificationId = "putInFridge-\(wine.id.uuidString)"

        // Calculate when to put wine in fridge
        let putInDate = dinnerDate.addingTimeInterval(-Double(wine.temperatureCategory.fridgeMinutes * 60))

        // Don't schedule if the time has already passed
        guard putInDate > Date() else {
            throw NotificationError.dateInPast
        }

        let content = UNMutableNotificationContent()
        content.title = "Metti in frigo il vino"
        content.body = "\(wine.displayName) per \(dinnerTitle). Servi a \(wine.temperatureCategory.servingTemperature)."
        content.sound = .default
        content.categoryIdentifier = "WINE_REMINDER"
        content.userInfo = [
            "wineId": wine.id.uuidString,
            "action": "putInFridge",
            "dinnerTitle": dinnerTitle
        ]

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: putInDate
            ),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(request)
        return notificationId
    }

    private func scheduleTakeOutNotification(
        wine: ConfirmedWine,
        dinnerDate: Date,
        dinnerTitle: String
    ) async throws -> String {
        let notificationId = "takeOut-\(wine.id.uuidString)"

        // Calculate when to take wine out of fridge
        let takeOutDate = dinnerDate.addingTimeInterval(-Double(wine.temperatureCategory.takeOutMinutes * 60))

        // Don't schedule if the time has already passed
        guard takeOutDate > Date() else {
            throw NotificationError.dateInPast
        }

        let content = UNMutableNotificationContent()
        content.title = "Togli il vino dal frigo"
        content.body = "\(wine.displayName) - lascialo a temperatura ambiente per \(wine.temperatureCategory.takeOutMinutes) minuti."
        content.sound = .default
        content.categoryIdentifier = "WINE_REMINDER"
        content.userInfo = [
            "wineId": wine.id.uuidString,
            "action": "takeOut",
            "dinnerTitle": dinnerTitle
        ]

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: takeOutDate
            ),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(request)
        return notificationId
    }

    // MARK: - Utility Methods

    /// Get all pending wine notifications
    func getPendingWineNotifications() async -> [UNNotificationRequest] {
        let pending = await notificationCenter.pendingNotificationRequests()
        return pending.filter { $0.content.categoryIdentifier == "WINE_REMINDER" }
    }

    /// Format a notification schedule summary for display
    func formatScheduleSummary(for wines: [ConfirmedWine], dinnerDate: Date) -> String {
        let summary = WineConfirmationSummary(confirmedWines: wines, dinnerDate: dinnerDate)
        let schedule = summary.fridgeSchedule()

        if schedule.isEmpty {
            return "Nessun vino necessita di refrigerazione."
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "it_IT")

        var lines: [String] = []
        for item in schedule {
            let putInTime = formatter.string(from: item.putInTime)
            lines.append("\(putInTime) - Metti in frigo: \(item.wine.displayName)")

            if let takeOutTime = item.takeOutTime {
                let takeOutStr = formatter.string(from: takeOutTime)
                lines.append("\(takeOutStr) - Togli dal frigo: \(item.wine.displayName)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Notification Errors

enum NotificationError: LocalizedError {
    case notAuthorized
    case dateInPast
    case schedulingFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Le notifiche non sono autorizzate. Abilita le notifiche nelle Impostazioni."
        case .dateInPast:
            return "La data per la notifica è già passata."
        case .schedulingFailed:
            return "Impossibile programmare la notifica."
        }
    }
}
