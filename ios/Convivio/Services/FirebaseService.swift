import Foundation
import FirebaseFirestore
import FirebaseFunctions
import FirebaseStorage
import Combine

@MainActor
class FirebaseService: ObservableObject {
    static let shared = FirebaseService()

    private let db = Firestore.firestore()
    private let functions = Functions.functions(region: "europe-west1")
    private let storage = Storage.storage()

    @Published var cellars: [Cellar] = []
    @Published var currentCellar: Cellar?
    @Published var bottles: [Bottle] = []
    @Published var dinners: [DinnerEvent] = []
    @Published var isLoading = false
    @Published var error: String?

    private var cellarsListener: ListenerRegistration?
    private var bottlesListener: ListenerRegistration?
    private var dinnersListener: ListenerRegistration?

    private init() {}

    // MARK: - Cellars

    func loadCellars(for userId: String) {
        cellarsListener?.remove()

        cellarsListener = db.collection("cellars")
            .whereField("members.\(userId)", isNotEqualTo: NSNull())
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    self.error = "Errore caricamento cantine: \(error.localizedDescription)"
                    return
                }

                guard let documents = snapshot?.documents else { return }

                self.cellars = documents.compactMap { doc in
                    try? doc.data(as: Cellar.self)
                }

                if self.currentCellar == nil, let first = self.cellars.first {
                    self.currentCellar = first
                    if let cellarId = first.id {
                        self.loadBottles(for: cellarId)
                        self.loadDinners(for: userId, cellarId: cellarId)
                    }
                }
            }
    }

    func ensureCellarExists(for userId: String) async throws {
        // If we already have a cellar, we're good
        if currentCellar != nil {
            return
        }

        // Check if user has any cellars
        let snapshot = try await db.collection("cellars")
            .whereField("members.\(userId)", isNotEqualTo: NSNull())
            .getDocuments()

        if let firstDoc = snapshot.documents.first,
           let cellar = try? firstDoc.data(as: Cellar.self) {
            currentCellar = cellar
            if let cellarId = cellar.id {
                loadBottles(for: cellarId)
            }
            return
        }

        // No cellar exists, create one
        let newCellar = Cellar(
            name: "La mia cantina",
            description: "Cantina personale",
            ownerId: userId,
            members: [userId: CellarMember(role: "owner", joinedAt: Timestamp())],
            stats: CellarStats(totalBottles: 0, totalValue: 0, wineTypes: [:]),
            createdAt: Timestamp(),
            updatedAt: Timestamp()
        )

        let cellarRef = db.collection("cellars").document()
        try cellarRef.setData(from: newCellar)

        var savedCellar = newCellar
        savedCellar.id = cellarRef.documentID
        currentCellar = savedCellar
        cellars = [savedCellar]

        if let cellarId = savedCellar.id {
            loadBottles(for: cellarId)
        }
    }

    func selectCellar(_ cellar: Cellar, userId: String) {
        currentCellar = cellar
        if let cellarId = cellar.id {
            loadBottles(for: cellarId)
            loadDinners(for: userId, cellarId: cellarId)
        }
    }

    // MARK: - Bottles

    func loadBottles(for cellarId: String) {
        bottlesListener?.remove()

        bottlesListener = db.collection("cellars").document(cellarId)
            .collection("bottles")
            .whereField("status", isEqualTo: BottleStatus.available.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    self.error = "Errore caricamento bottiglie: \(error.localizedDescription)"
                    return
                }

                guard let documents = snapshot?.documents else { return }

                Task {
                    var loadedBottles: [Bottle] = []

                    for doc in documents {
                        guard var bottle = try? doc.data(as: Bottle.self) else { continue }

                        // Load wine data
                        if let wineDoc = try? await self.db.collection("wines")
                            .document(bottle.wineId).getDocument(),
                           let wine = try? wineDoc.data(as: Wine.self) {
                            bottle.wine = wine
                        }

                        loadedBottles.append(bottle)
                    }

                    await MainActor.run {
                        self.bottles = loadedBottles.sorted { b1, b2 in
                            (b1.wine?.name ?? "") < (b2.wine?.name ?? "")
                        }
                    }
                }
            }
    }

    func addBottle(_ bottle: Bottle, wine: Wine) async throws {
        guard let cellarId = currentCellar?.id else {
            throw FirebaseServiceError.noCellarSelected
        }

        // Check if wine exists or create it
        var wineId = wine.id
        if wineId == nil {
            let wineRef = db.collection("wines").document()
            var newWine = wine
            try wineRef.setData(from: newWine)
            wineId = wineRef.documentID
        }

        guard let finalWineId = wineId else {
            throw FirebaseServiceError.invalidData
        }

        // Create bottle
        var newBottle = bottle
        newBottle.wineId = finalWineId
        newBottle.cellarId = cellarId

        let bottleRef = db.collection("cellars").document(cellarId)
            .collection("bottles").document()
        try bottleRef.setData(from: newBottle)

        // Update cellar stats
        try await updateCellarStats(cellarId: cellarId)
    }

    func updateBottle(_ bottle: Bottle) async throws {
        guard let cellarId = currentCellar?.id,
              let bottleId = bottle.id else {
            throw FirebaseServiceError.invalidData
        }

        try db.collection("cellars").document(cellarId)
            .collection("bottles").document(bottleId)
            .setData(from: bottle, merge: true)
    }

    func consumeBottle(_ bottle: Bottle) async throws {
        guard let cellarId = currentCellar?.id,
              let bottleId = bottle.id else {
            throw FirebaseServiceError.invalidData
        }

        try await db.collection("cellars").document(cellarId)
            .collection("bottles").document(bottleId)
            .updateData([
                "status": BottleStatus.consumed.rawValue,
                "updatedAt": Timestamp()
            ])

        try await updateCellarStats(cellarId: cellarId)
    }

    private func updateCellarStats(cellarId: String) async throws {
        let bottlesSnapshot = try await db.collection("cellars").document(cellarId)
            .collection("bottles")
            .whereField("status", isEqualTo: BottleStatus.available.rawValue)
            .getDocuments()

        var totalBottles = 0
        var totalValue: Double = 0
        var wineTypes: [String: Int] = [:]

        for doc in bottlesSnapshot.documents {
            guard let bottle = try? doc.data(as: Bottle.self) else { continue }

            totalBottles += bottle.quantity

            if let price = bottle.purchasePrice {
                totalValue += price * Double(bottle.quantity)
            }

            if let wine = bottle.wine {
                wineTypes[wine.type.rawValue, default: 0] += bottle.quantity
            }
        }

        try await db.collection("cellars").document(cellarId).updateData([
            "stats.totalBottles": totalBottles,
            "stats.totalValue": totalValue,
            "stats.wineTypes": wineTypes,
            "updatedAt": Timestamp()
        ])
    }

    // MARK: - Dinners

    func loadDinners(for userId: String, cellarId: String) {
        dinnersListener?.remove()

        dinnersListener = db.collection("dinners")
            .whereField("hostId", isEqualTo: userId)
            .whereField("cellarId", isEqualTo: cellarId)
            .order(by: "date", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    self.error = "Errore caricamento cene: \(error.localizedDescription)"
                    return
                }

                guard let documents = snapshot?.documents else { return }

                self.dinners = documents.compactMap { doc in
                    try? doc.data(as: DinnerEvent.self)
                }
            }
    }

    func createDinner(_ dinner: DinnerEvent) async throws -> DinnerEvent {
        guard let cellarId = currentCellar?.id else {
            throw FirebaseServiceError.noCellarSelected
        }

        var newDinner = dinner
        newDinner.cellarId = cellarId

        let dinnerRef = db.collection("dinners").document()
        try dinnerRef.setData(from: newDinner)

        var savedDinner = newDinner
        savedDinner.id = dinnerRef.documentID

        // Auto-generate menu
        do {
            let menu = try await proposeDinnerMenu(for: savedDinner)
            savedDinner.menu = menu

            try await dinnerRef.updateData([
                "menu": menu.asDictionary()
            ])
        } catch {
            print("Menu generation failed: \(error)")
        }

        return savedDinner
    }

    func updateDinner(_ dinner: DinnerEvent) async throws {
        guard let dinnerId = dinner.id else {
            throw FirebaseServiceError.invalidData
        }

        try db.collection("dinners").document(dinnerId)
            .setData(from: dinner, merge: true)
    }

    func deleteDinner(_ dinner: DinnerEvent) async throws {
        guard let dinnerId = dinner.id else {
            throw FirebaseServiceError.invalidData
        }

        try await db.collection("dinners").document(dinnerId).delete()
    }

    // MARK: - Cloud Functions

    func extractWineFromPhoto(photoUrl: String, userId: String) async throws -> ExtractWineResponse {
        let callable = functions.httpsCallable("extractWineFromPhoto")

        let result = try await callable.call([
            "photoUrl": photoUrl,
            "userId": userId
        ])

        guard let data = result.data as? [String: Any] else {
            throw FirebaseServiceError.invalidResponse
        }

        let jsonData = try JSONSerialization.data(withJSONObject: data)
        return try JSONDecoder().decode(ExtractWineResponse.self, from: jsonData)
    }

    func proposeDinnerMenu(for dinner: DinnerEvent) async throws -> MenuProposal {
        guard let dinnerId = dinner.id,
              let cellarId = dinner.cellarId as String? else {
            throw FirebaseServiceError.invalidData
        }

        let callable = functions.httpsCallable("proposeDinnerMenu")

        let result = try await callable.call([
            "dinnerId": dinnerId,
            "cellarId": cellarId,
            "userId": dinner.hostId
        ])

        guard let data = result.data as? [String: Any],
              let success = data["success"] as? Bool,
              success,
              let menuData = data["menu"] as? [String: Any] else {
            let errorMsg = (result.data as? [String: Any])?["error"] as? String ?? "Unknown error"
            throw FirebaseServiceError.functionError(errorMsg)
        }

        let jsonData = try JSONSerialization.data(withJSONObject: menuData)
        return try JSONDecoder().decode(MenuProposal.self, from: jsonData)
    }

    func chatWithSommelier(message: String, userId: String, cellarId: String) async throws -> ChatMessage {
        let callable = functions.httpsCallable("chatWithSommelier")

        let result = try await callable.call([
            "message": message,
            "userId": userId,
            "cellarId": cellarId
        ])

        guard let data = result.data as? [String: Any],
              let success = data["success"] as? Bool,
              success,
              let messageData = data["message"] as? [String: Any] else {
            let errorMsg = (result.data as? [String: Any])?["error"] as? String ?? "Unknown error"
            throw FirebaseServiceError.functionError(errorMsg)
        }

        let jsonData = try JSONSerialization.data(withJSONObject: messageData)
        return try JSONDecoder().decode(ChatMessage.self, from: jsonData)
    }

    // MARK: - Storage

    func uploadPhoto(_ imageData: Data, path: String) async throws -> String {
        let storageRef = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        let downloadUrl = try await storageRef.downloadURL()
        return downloadUrl.absoluteString
    }

    // MARK: - Cleanup

    func cleanup() {
        cellarsListener?.remove()
        bottlesListener?.remove()
        dinnersListener?.remove()
        cellars = []
        currentCellar = nil
        bottles = []
        dinners = []
    }
}

// MARK: - Errors

enum FirebaseServiceError: LocalizedError {
    case noCellarSelected
    case invalidData
    case invalidResponse
    case functionError(String)

    var errorDescription: String? {
        switch self {
        case .noCellarSelected:
            return "Nessuna cantina selezionata"
        case .invalidData:
            return "Dati non validi"
        case .invalidResponse:
            return "Risposta non valida dal server"
        case .functionError(let message):
            return message
        }
    }
}

// MARK: - Encodable Extension

extension Encodable {
    func asDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FirebaseServiceError.invalidData
        }
        return dictionary
    }
}
