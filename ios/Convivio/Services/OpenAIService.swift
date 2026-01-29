import Foundation
import UIKit
import Vision
import os.log

// MARK: - OpenAI Service

actor OpenAIService {
    static let shared = OpenAIService()

    private let baseURL = "https://api.openai.com/v1"
    private var apiKey: String?

    // In-memory log storage
    private var _logs: [AILogEntry] = []
    private let logger = Logger(subsystem: "it.mikesoft.convivio", category: "OpenAI")

    private init() {}

    // MARK: - Logging

    var logs: [AILogEntry] {
        _logs
    }

    func clearLogs() {
        _logs.removeAll()
        logger.info("🧹 Logs cleared")
    }

    private func log(endpoint: String, prompt: String, response: String, duration: TimeInterval, success: Bool, error: String? = nil) {
        let entry = AILogEntry(
            timestamp: Date(),
            endpoint: endpoint,
            prompt: prompt,
            response: response,
            duration: duration,
            success: success,
            error: error
        )
        _logs.insert(entry, at: 0) // Most recent first

        // Keep only last 50 entries
        if _logs.count > 50 {
            _logs = Array(_logs.prefix(50))
        }

        // Console logging
        print("\n" + String(repeating: "=", count: 80))
        print("🤖 OpenAI API Call - \(entry.formattedTimestamp)")
        print(String(repeating: "-", count: 80))
        print("📍 Endpoint: \(endpoint)")
        print("⏱️  Duration: \(String(format: "%.2f", duration))s")
        print(String(repeating: "-", count: 80))
        print("📤 PROMPT:")
        print(prompt.prefix(2000))
        if prompt.count > 2000 { print("... [truncated, \(prompt.count) chars total]") }
        print(String(repeating: "-", count: 80))
        if success {
            print("📥 RESPONSE:")
            print(response.prefix(2000))
            if response.count > 2000 { print("... [truncated, \(response.count) chars total]") }
        } else {
            print("❌ ERROR: \(error ?? "Unknown")")
        }
        print(String(repeating: "=", count: 80) + "\n")

        // OS Log
        if success {
            logger.info("✅ \(endpoint) completed in \(String(format: "%.2f", duration))s")
        } else {
            logger.error("❌ \(endpoint) failed: \(error ?? "Unknown")")
        }
    }

    func setApiKey(_ key: String) {
        self.apiKey = key
    }

    func hasApiKey() -> Bool {
        return apiKey != nil && !apiKey!.isEmpty
    }

    // MARK: - Wine Extraction from Photo

    func extractWineFromPhoto(_ image: UIImage) async throws -> ExtractionResult {
        // First, use Apple Vision for OCR
        let ocrText = try await performOCR(on: image)

        // Then use GPT to interpret the text
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            // Return basic extraction without AI if no API key
            return ExtractionResult(
                name: ocrText.components(separatedBy: "\n").first,
                confidence: 0.3
            )
        }

        // Convert image to base64 for GPT-4 Vision
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw OpenAIError.invalidImage
        }
        let base64Image = imageData.base64EncodedString()

        let prompt = """
        Analizza questa etichetta di vino e estrai le seguenti informazioni in formato JSON:
        {
            "name": "nome del vino",
            "producer": "produttore/cantina",
            "vintage": "annata (solo anno, es: 2019)",
            "type": "red|white|rosé|sparkling|dessert|fortified",
            "region": "regione di produzione",
            "country": "paese",
            "grapes": ["vitigno1", "vitigno2"],
            "alcohol": 13.5,
            "confidence": 0.85
        }

        OCR Text rilevato: \(ocrText)

        Rispondi SOLO con il JSON, senza markdown o altro testo.
        """

        let response = try await callGPT4Vision(prompt: prompt, base64Image: base64Image)
        return try parseExtractionResult(response)
    }

    private func performOCR(on image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OpenAIError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")

                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["it-IT", "en-US", "fr-FR"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Menu Generation (for MenuGeneratorService)

    func generateMenuWithGPT(prompt: String) async throws -> String {
        return try await callGPT(prompt: prompt)
    }

    // MARK: - Menu Proposal

    func proposeDinnerMenu(
        dinner: DinnerEvent,
        wines: [Wine],
        bottles: [Bottle]
    ) async throws -> MenuProposal {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw OpenAIError.noApiKey
        }

        // Build wine inventory summary
        let wineInventory = bottles.compactMap { bottle -> String? in
            guard let wine = bottle.wine, bottle.quantity > 0 else { return nil }
            return "- \(wine.displayName) (\(wine.type.displayName), \(bottle.quantity) bottiglie)"
        }.joined(separator: "\n")

        let guestInfo = dinner.guests.map { guest in
            var info = "- \(guest.name)"
            if !guest.dietaryRestrictions.isEmpty {
                info += " (restrizioni: \(guest.dietaryRestrictions.joined(separator: ", ")))"
            }
            return info
        }.joined(separator: "\n")

        let prompt = """
        Sei un sommelier esperto. Genera un menu per questa cena:

        CENA:
        - Titolo: \(dinner.title)
        - Data: \(formatDate(dinner.date))
        - Ospiti: \(dinner.guestCount) persone
        - Occasione: \(dinner.occasion ?? "Cena informale")
        \(dinner.notes.map { "- Note speciali: \($0)" } ?? "")

        OSPITI:
        \(guestInfo.isEmpty ? "Nessuna info specifica" : guestInfo)

        VINI DISPONIBILI IN CANTINA:
        \(wineInventory.isEmpty ? "Cantina vuota" : wineInventory)

        Genera un menu in formato JSON con questa struttura:
        {
            "courses": [
                {
                    "course": "antipasto|primo|secondo|dolce",
                    "name": "Nome piatto",
                    "description": "Descrizione breve",
                    "dietaryFlags": ["vegetarian", "gluten-free"],
                    "prepTime": 30,
                    "cellarWine": {
                        "name": "Nome vino dalla cantina",
                        "reasoning": "Perché questo abbinamento"
                    },
                    "marketWine": {
                        "name": "Alternativa da acquistare",
                        "reasoning": "Perché questo abbinamento"
                    }
                }
            ],
            "wineStrategy": "Strategia generale per i vini",
            "aiNotes": "Note aggiuntive del sommelier"
        }

        IMPORTANTE:
        - Per cellarWine usa SOLO vini dalla lista cantina sopra
        - Se la cantina è vuota, ometti cellarWine
        - Considera le restrizioni alimentari degli ospiti
        - Le note della cena hanno PRIORITÀ MASSIMA

        Rispondi SOLO con il JSON.
        """

        let response = try await callGPT(prompt: prompt)
        return try parseMenuProposal(response)
    }

    // MARK: - Chat with Sommelier

    func chatWithSommelier(
        message: String,
        history: [ChatMessage],
        wines: [Wine],
        bottles: [Bottle]
    ) async throws -> String {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw OpenAIError.noApiKey
        }

        // Build context
        let wineInventory = bottles.compactMap { bottle -> String? in
            guard let wine = bottle.wine, bottle.quantity > 0 else { return nil }
            var info = "\(wine.displayName) - \(wine.type.displayName)"
            if let region = wine.region { info += ", \(region)" }
            info += " (\(bottle.quantity) bottiglie)"
            if let location = bottle.location { info += " [Posizione: \(location)]" }
            return info
        }.joined(separator: "\n")

        let systemPrompt = """
        Sei Convivio, un sommelier AI esperto e amichevole. Aiuti l'utente a gestire la sua cantina personale.

        CANTINA DELL'UTENTE:
        \(wineInventory.isEmpty ? "La cantina è vuota." : wineInventory)

        CAPACITÀ:
        - Consigliare vini per occasioni specifiche
        - Suggerire abbinamenti cibo-vino
        - Fornire informazioni su vini specifici
        - Aiutare a organizzare la cantina
        - Rispondere a domande sul vino in generale

        Rispondi sempre in italiano, in modo cordiale e competente.
        """

        var messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]

        // Add history (last 10 messages)
        for msg in history.suffix(10) {
            messages.append([
                "role": msg.role == .user ? "user" : "assistant",
                "content": msg.content
            ])
        }

        messages.append(["role": "user", "content": message])

        return try await callGPTChat(messages: messages)
    }

    // MARK: - API Calls

    private func callGPT(prompt: String) async throws -> String {
        guard let apiKey = apiKey else { throw OpenAIError.noApiKey }

        let startTime = Date()
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180 // 3 minutes for complex menu generation

        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 16000
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Use custom session with longer timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 180
        config.timeoutIntervalForResource = 300
        let session = URLSession(configuration: config)

        do {
            let (data, response) = try await session.data(for: request)
            let duration = Date().timeIntervalSince(startTime)

            guard let httpResponse = response as? HTTPURLResponse else {
                log(endpoint: "chat/completions", prompt: prompt, response: "", duration: duration, success: false, error: "Invalid response")
                throw OpenAIError.invalidResponse
            }

            if httpResponse.statusCode == 401 {
                log(endpoint: "chat/completions", prompt: prompt, response: "", duration: duration, success: false, error: "Invalid API key (401)")
                throw OpenAIError.invalidApiKey
            }

            if httpResponse.statusCode != 200 {
                log(endpoint: "chat/completions", prompt: prompt, response: "", duration: duration, success: false, error: "API error (\(httpResponse.statusCode))")
                throw OpenAIError.apiError(statusCode: httpResponse.statusCode)
            }

            let result = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
            let responseText = result.choices.first?.message.content ?? ""

            log(endpoint: "chat/completions", prompt: prompt, response: responseText, duration: duration, success: true)

            return responseText
        } catch let error as OpenAIError {
            throw error
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            log(endpoint: "chat/completions", prompt: prompt, response: "", duration: duration, success: false, error: error.localizedDescription)
            throw error
        }
    }

    private func callGPT4Vision(prompt: String, base64Image: String) async throws -> String {
        guard let apiKey = apiKey else { throw OpenAIError.noApiKey }

        let startTime = Date()
        let logPrompt = "\(prompt)\n\n[IMAGE: \(base64Image.count) bytes base64]"

        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 1000
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let duration = Date().timeIntervalSince(startTime)

            guard let httpResponse = response as? HTTPURLResponse else {
                log(endpoint: "chat/completions (vision)", prompt: logPrompt, response: "", duration: duration, success: false, error: "Invalid response")
                throw OpenAIError.invalidResponse
            }

            if httpResponse.statusCode == 401 {
                log(endpoint: "chat/completions (vision)", prompt: logPrompt, response: "", duration: duration, success: false, error: "Invalid API key (401)")
                throw OpenAIError.invalidApiKey
            }

            if httpResponse.statusCode != 200 {
                log(endpoint: "chat/completions (vision)", prompt: logPrompt, response: "", duration: duration, success: false, error: "API error (\(httpResponse.statusCode))")
                throw OpenAIError.apiError(statusCode: httpResponse.statusCode)
            }

            let result = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
            let responseText = result.choices.first?.message.content ?? ""

            log(endpoint: "chat/completions (vision)", prompt: logPrompt, response: responseText, duration: duration, success: true)

            return responseText
        } catch let error as OpenAIError {
            throw error
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            log(endpoint: "chat/completions (vision)", prompt: logPrompt, response: "", duration: duration, success: false, error: error.localizedDescription)
            throw error
        }
    }

    private func callGPTChat(messages: [[String: String]]) async throws -> String {
        guard let apiKey = apiKey else { throw OpenAIError.noApiKey }

        let startTime = Date()

        // Build prompt log from messages
        let logPrompt = messages.map { msg in
            "[\(msg["role"] ?? "?")]: \(msg["content"] ?? "")"
        }.joined(separator: "\n\n")

        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages,
            "temperature": 0.8,
            "max_tokens": 1000
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let duration = Date().timeIntervalSince(startTime)

            guard let httpResponse = response as? HTTPURLResponse else {
                log(endpoint: "chat/completions (chat)", prompt: logPrompt, response: "", duration: duration, success: false, error: "Invalid response")
                throw OpenAIError.invalidResponse
            }

            if httpResponse.statusCode == 401 {
                log(endpoint: "chat/completions (chat)", prompt: logPrompt, response: "", duration: duration, success: false, error: "Invalid API key (401)")
                throw OpenAIError.invalidApiKey
            }

            if httpResponse.statusCode != 200 {
                log(endpoint: "chat/completions (chat)", prompt: logPrompt, response: "", duration: duration, success: false, error: "API error (\(httpResponse.statusCode))")
                throw OpenAIError.apiError(statusCode: httpResponse.statusCode)
            }

            let result = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
            let responseText = result.choices.first?.message.content ?? ""

            log(endpoint: "chat/completions (chat)", prompt: logPrompt, response: responseText, duration: duration, success: true)

            return responseText
        } catch let error as OpenAIError {
            throw error
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            log(endpoint: "chat/completions (chat)", prompt: logPrompt, response: "", duration: duration, success: false, error: error.localizedDescription)
            throw error
        }
    }

    // MARK: - Parsing

    private func parseExtractionResult(_ json: String) throws -> ExtractionResult {
        // Clean JSON from markdown code blocks
        var cleanJson = json
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleanJson.data(using: .utf8) else {
            throw OpenAIError.parseError
        }

        return try JSONDecoder().decode(ExtractionResult.self, from: data)
    }

    private func parseMenuProposal(_ json: String) throws -> MenuProposal {
        var cleanJson = json
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleanJson.data(using: .utf8) else {
            throw OpenAIError.parseError
        }

        var proposal = try JSONDecoder().decode(MenuProposal.self, from: data)
        proposal.generatedAt = Date()
        return proposal
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }
}

// MARK: - Response Types

private struct ChatCompletionResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: Message
    }

    struct Message: Codable {
        let content: String
    }
}

// MARK: - Errors

enum OpenAIError: LocalizedError {
    case noApiKey
    case invalidApiKey
    case invalidImage
    case invalidResponse
    case apiError(statusCode: Int)
    case parseError

    var errorDescription: String? {
        switch self {
        case .noApiKey:
            return "API key OpenAI non configurata. Vai in Profilo per inserirla."
        case .invalidApiKey:
            return "API key OpenAI non valida. Verifica la chiave in Profilo."
        case .invalidImage:
            return "Immagine non valida"
        case .invalidResponse:
            return "Risposta non valida dal server"
        case .apiError(let code):
            return "Errore API: \(code)"
        case .parseError:
            return "Errore nel parsing della risposta"
        }
    }
}
