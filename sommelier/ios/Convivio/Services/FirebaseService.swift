//
//  FirebaseService.swift
//  Convivio
//
//  Servizio centralizzato per Firestore e Cloud Functions
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import FirebaseFunctions
import UIKit

@MainActor
class FirebaseService {
    static let shared = FirebaseService()

    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private let functions = Functions.functions()

    private var userId: String? {
        AuthManager.shared.user?.uid
    }

    // MARK: - Wine Operations

    func getWines() async throws -> [Wine] {
        let snapshot = try await db.collection("wines").getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Wine.self) }
    }

    func createWine(_ wine: Wine) async throws -> String {
        let ref = try db.collection("wines").addDocument(from: wine)
        return ref.documentID
    }

    func searchWines(query: String) async throws -> [Wine] {
        // Firestore doesn't support full-text search, so we do a prefix match on name
        let snapshot = try await db.collection("wines")
            .whereField("name", isGreaterThanOrEqualTo: query)
            .whereField("name", isLessThanOrEqualTo: query + "\u{f8ff}")
            .limit(to: 10)
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: Wine.self) }
    }

    // MARK: - Cellar Operations

    func getUserCellars() async throws -> [Cellar] {
        guard let userId else { throw FirebaseError.notAuthenticated }

        let snapshot = try await db.collection("cellars")
            .whereField("members.\(userId)", isNotEqualTo: NSNull())
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: Cellar.self) }
    }

    func getOrCreateDefaultCellar() async throws -> Cellar {
        guard let userId else { throw FirebaseError.notAuthenticated }

        let cellars = try await getUserCellars()

        if let existing = cellars.first {
            return existing
        }

        // Create default cellar
        let newCellar = Cellar(
            id: nil,
            name: "La mia cantina",
            description: "Cantina personale",
            members: [userId: .owner],
            createdAt: nil,
            createdBy: userId
        )

        let ref = try db.collection("cellars").addDocument(from: newCellar)

        // Create default location
        let defaultLocation = Location(
            id: nil,
            cellarId: ref.documentID,
            shelf: "A",
            row: 1,
            slot: nil,
            description: "Scaffale principale",
            capacity: 50
        )
        try ref.collection("locations").addDocument(from: defaultLocation)

        var created = newCellar
        created.id = ref.documentID
        return created
    }

    func getLocations(cellarId: String) async throws -> [Location] {
        let snapshot = try await db.collection("cellars").document(cellarId)
            .collection("locations")
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: Location.self) }
    }

    // MARK: - Bottle Operations

    func addBottle(to cellarId: String, wineId: String, locationId: String, price: Double?) async throws {
        guard let userId else { throw FirebaseError.notAuthenticated }

        let bottle = Bottle(
            id: nil,
            wineId: wineId,
            locationId: locationId,
            status: .available,
            acquiredAt: Timestamp(date: Date()),
            acquiredPrice: price,
            consumedAt: nil,
            notes: nil,
            createdAt: nil,
            createdBy: userId
        )

        let cellarRef = db.collection("cellars").document(cellarId)
        let bottleRef = try cellarRef.collection("bottles").addDocument(from: bottle)

        // Record movement
        try await cellarRef.collection("movements").addDocument(data: [
            "bottleId": bottleRef.documentID,
            "type": "in",
            "reason": "acquired",
            "performedBy": userId,
            "performedAt": FieldValue.serverTimestamp()
        ])
    }

    func getAvailableBottles(cellarId: String) async throws -> [Bottle] {
        let snapshot = try await db.collection("cellars").document(cellarId)
            .collection("bottles")
            .whereField("status", isEqualTo: "available")
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: Bottle.self) }
    }

    // MARK: - Rating Operations

    func getRating(for wineId: String) async throws -> Rating? {
        guard let userId else { throw FirebaseError.notAuthenticated }

        let snapshot = try await db.collection("users").document(userId)
            .collection("ratings")
            .whereField("wineId", isEqualTo: wineId)
            .limit(to: 1)
            .getDocuments()

        return try snapshot.documents.first?.data(as: Rating.self)
    }

    func setRating(_ rating: Int, isFavorite: Bool, notes: String?, for wineId: String) async throws {
        guard let userId else { throw FirebaseError.notAuthenticated }

        let ratingRef = db.collection("users").document(userId)
            .collection("ratings")

        // Check if exists
        let existing = try await getRating(for: wineId)

        if let existingId = existing?.id {
            try await ratingRef.document(existingId).updateData([
                "rating": rating,
                "isFavorite": isFavorite,
                "notes": notes as Any,
                "updatedAt": FieldValue.serverTimestamp()
            ])
        } else {
            let newRating = Rating(
                id: nil,
                wineId: wineId,
                rating: rating,
                isFavorite: isFavorite,
                notes: notes,
                createdAt: nil,
                updatedAt: nil
            )
            try ratingRef.addDocument(from: newRating)
        }
    }

    // MARK: - Friends Operations

    func getFriends() async throws -> [Friend] {
        guard let userId else { throw FirebaseError.notAuthenticated }

        let snapshot = try await db.collection("users").document(userId)
            .collection("friends")
            .order(by: "name")
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: Friend.self) }
    }

    func addFriend(_ friend: Friend) async throws -> String {
        guard let userId else { throw FirebaseError.notAuthenticated }

        let ref = try db.collection("users").document(userId)
            .collection("friends")
            .addDocument(from: friend)

        return ref.documentID
    }

    func deleteFriend(_ friendId: String) async throws {
        guard let userId else { throw FirebaseError.notAuthenticated }

        // Delete friend's preferences first
        let prefsSnapshot = try await db.collection("users").document(userId)
            .collection("foodPreferences")
            .whereField("friendId", isEqualTo: friendId)
            .getDocuments()

        let batch = db.batch()
        for doc in prefsSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }

        // Delete friend
        batch.deleteDocument(
            db.collection("users").document(userId)
                .collection("friends").document(friendId)
        )

        try await batch.commit()
    }

    // MARK: - Food Preferences Operations

    func getFoodPreferences(for friendId: String) async throws -> [FoodPreference] {
        guard let userId else { throw FirebaseError.notAuthenticated }

        let snapshot = try await db.collection("users").document(userId)
            .collection("foodPreferences")
            .whereField("friendId", isEqualTo: friendId)
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: FoodPreference.self) }
    }

    func addFoodPreference(_ pref: FoodPreference, to friendId: String) async throws {
        guard let userId else { throw FirebaseError.notAuthenticated }

        var newPref = pref
        newPref.friendId = friendId

        try db.collection("users").document(userId)
            .collection("foodPreferences")
            .addDocument(from: newPref)
    }

    func deleteFoodPreference(_ prefId: String) async throws {
        guard let userId else { throw FirebaseError.notAuthenticated }

        try await db.collection("users").document(userId)
            .collection("foodPreferences")
            .document(prefId)
            .delete()
    }

    // MARK: - Dinner Operations

    func getDinners() async throws -> [DinnerEvent] {
        guard let userId else { throw FirebaseError.notAuthenticated }

        let snapshot = try await db.collection("users").document(userId)
            .collection("dinners")
            .order(by: "date", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: DinnerEvent.self) }
    }

    func createDinner(_ dinner: DinnerEvent) async throws -> String {
        guard let userId else { throw FirebaseError.notAuthenticated }

        let ref = try db.collection("users").document(userId)
            .collection("dinners")
            .addDocument(from: dinner)

        return ref.documentID
    }

    func updateDinner(_ dinnerId: String, menuProposal: MenuProposal) async throws {
        guard let userId else { throw FirebaseError.notAuthenticated }

        try await db.collection("users").document(userId)
            .collection("dinners")
            .document(dinnerId)
            .updateData([
                "menuProposal": try Firestore.Encoder().encode(menuProposal),
                "updatedAt": FieldValue.serverTimestamp()
            ])
    }

    func addGuestToDinner(_ dinnerId: String, friendId: String) async throws {
        guard let userId else { throw FirebaseError.notAuthenticated }

        try await db.collection("users").document(userId)
            .collection("dinners")
            .document(dinnerId)
            .collection("guests")
            .document(friendId)
            .setData(["addedAt": FieldValue.serverTimestamp()])
    }

    func getDinnerGuests(_ dinnerId: String) async throws -> [String] {
        guard let userId else { throw FirebaseError.notAuthenticated }

        let snapshot = try await db.collection("users").document(userId)
            .collection("dinners")
            .document(dinnerId)
            .collection("guests")
            .getDocuments()

        return snapshot.documents.map { $0.documentID }
    }

    // MARK: - Stats

    func getUserStats() async throws -> UserStats {
        guard let userId else { throw FirebaseError.notAuthenticated }

        var stats = UserStats()

        // Count bottles
        let cellars = try await getUserCellars()
        for cellar in cellars {
            guard let cellarId = cellar.id else { continue }
            let bottles = try await getAvailableBottles(cellarId: cellarId)
            stats.totalBottles += bottles.count
        }

        // Count ratings
        let ratingsSnapshot = try await db.collection("users").document(userId)
            .collection("ratings")
            .getDocuments()
        stats.ratedWines = ratingsSnapshot.count

        // Count dinners
        let dinnersSnapshot = try await db.collection("users").document(userId)
            .collection("dinners")
            .getDocuments()
        stats.totalDinners = dinnersSnapshot.count

        return stats
    }

    // MARK: - Chat/Conversations

    func getConversations() async throws -> [Conversation] {
        guard let userId else { throw FirebaseError.notAuthenticated }

        let snapshot = try await db.collection("users").document(userId)
            .collection("conversations")
            .order(by: "updatedAt", descending: true)
            .limit(to: 20)
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: Conversation.self) }
    }

    func createConversation() async throws -> String {
        guard let userId else { throw FirebaseError.notAuthenticated }

        let conversation = Conversation(
            id: nil,
            title: nil,
            createdAt: nil,
            updatedAt: nil
        )

        let ref = try db.collection("users").document(userId)
            .collection("conversations")
            .addDocument(from: conversation)

        return ref.documentID
    }

    func getMessages(conversationId: String) async throws -> [ChatMessage] {
        guard let userId else { throw FirebaseError.notAuthenticated }

        let snapshot = try await db.collection("users").document(userId)
            .collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "createdAt")
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: ChatMessage.self) }
    }

    func addMessage(_ message: ChatMessage, to conversationId: String) async throws {
        guard let userId else { throw FirebaseError.notAuthenticated }

        try db.collection("users").document(userId)
            .collection("conversations")
            .document(conversationId)
            .collection("messages")
            .addDocument(from: message)

        // Update conversation timestamp
        try await db.collection("users").document(userId)
            .collection("conversations")
            .document(conversationId)
            .updateData(["updatedAt": FieldValue.serverTimestamp()])
    }

    // MARK: - Storage Operations

    func uploadImage(_ image: UIImage, path: String) async throws -> URL {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw FirebaseError.invalidImage
        }

        let ref = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()

        return url
    }

    // MARK: - Cloud Functions

    func extractWineLabel(imageUrl: String) async throws -> ExtractionResult {
        let result = try await functions.httpsCallable("extractWineLabel").call([
            "imageUrl": imageUrl
        ])

        guard let data = result.data as? [String: Any] else {
            throw FirebaseError.invalidResponse
        }

        return try parseExtractionResult(data)
    }

    func chatWithSommelier(message: String, conversationId: String?, cellarContext: Bool = true) async throws -> ChatResponse {
        var params: [String: Any] = [
            "message": message,
            "includeCellarContext": cellarContext
        ]

        if let convId = conversationId {
            params["conversationId"] = convId
        }

        let result = try await functions.httpsCallable("chatWithSommelier").call(params)

        guard let data = result.data as? [String: Any] else {
            throw FirebaseError.invalidResponse
        }

        return ChatResponse(
            message: data["message"] as? String ?? "",
            conversationId: data["conversationId"] as? String,
            wineIds: data["wineIds"] as? [String] ?? []
        )
    }

    func generateMenuProposal(dinnerId: String) async throws -> MenuProposal {
        let result = try await functions.httpsCallable("generateMenuProposal").call([
            "dinnerId": dinnerId
        ])

        guard let data = result.data as? [String: Any] else {
            throw FirebaseError.invalidResponse
        }

        return try parseMenuProposal(data)
    }

    // MARK: - GDPR Operations

    func exportUserData() async throws -> [String: Any] {
        let result = try await functions.httpsCallable("exportUserData").call([:])

        guard let data = result.data as? [String: Any] else {
            throw FirebaseError.invalidResponse
        }

        return data
    }

    func deleteUserAccount() async throws {
        _ = try await functions.httpsCallable("deleteUserAccount").call([:])
        AuthManager.shared.signOut()
    }

    // MARK: - Parsing Helpers

    private func parseExtractionResult(_ data: [String: Any]) throws -> ExtractionResult {
        let fieldsData = data["extractedFields"] as? [String: Any] ?? [:]

        func parseField(_ key: String) -> ExtractedField? {
            guard let field = fieldsData[key] as? [String: Any],
                  let value = field["value"] as? String,
                  let confidence = field["confidence"] as? Double else {
                return nil
            }
            return ExtractedField(value: value, confidence: confidence)
        }

        let fields = ExtractedFields(
            name: parseField("name"),
            producer: parseField("producer"),
            vintage: parseField("vintage"),
            type: parseField("type"),
            region: parseField("region"),
            country: parseField("country"),
            alcoholContent: parseField("alcoholContent"),
            grapes: parseField("grapes")
        )

        return ExtractionResult(
            id: data["id"] as? String,
            photoAssetId: data["photoAssetId"] as? String ?? "",
            rawOcrText: data["rawOcrText"] as? String ?? "",
            extractedFields: fields,
            overallConfidence: data["overallConfidence"] as? Double ?? 0,
            wasManuallyEdited: false,
            finalWineId: nil,
            createdAt: nil
        )
    }

    private func parseMenuProposal(_ data: [String: Any]) throws -> MenuProposal {
        let coursesData = data["courses"] as? [[String: Any]] ?? []

        let courses: [MenuCourse] = coursesData.compactMap { courseData in
            guard let courseStr = courseData["course"] as? String,
                  let course = CourseType(rawValue: courseStr),
                  let name = courseData["name"] as? String,
                  let description = courseData["description"] as? String else {
                return nil
            }

            return MenuCourse(
                course: course,
                name: name,
                description: description,
                dietaryFlags: courseData["dietaryFlags"] as? [String] ?? [],
                prepTime: courseData["prepTime"] as? Int ?? 0,
                notes: courseData["notes"] as? String
            )
        }

        return MenuProposal(
            courses: courses,
            reasoning: data["reasoning"] as? String ?? "",
            seasonContext: data["seasonContext"] as? String ?? "",
            guestConsiderations: data["guestConsiderations"] as? [String] ?? [],
            totalPrepTime: data["totalPrepTime"] as? Int ?? 0,
            generatedAt: nil
        )
    }
}

// MARK: - Response Types

struct ChatResponse {
    let message: String
    let conversationId: String?
    let wineIds: [String]
}

// MARK: - Errors

enum FirebaseError: LocalizedError {
    case notAuthenticated
    case invalidImage
    case invalidResponse
    case notFound

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Devi effettuare l'accesso"
        case .invalidImage:
            return "Impossibile elaborare l'immagine"
        case .invalidResponse:
            return "Risposta non valida dal server"
        case .notFound:
            return "Elemento non trovato"
        }
    }
}
