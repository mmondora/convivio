import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChatMessage.createdAt) private var messages: [ChatMessage]
    @Query private var wines: [Wine]
    @Query(filter: #Predicate<Bottle> { $0.quantity > 0 }) private var bottles: [Bottle]
    @Query private var settings: [AppSettings]

    @State private var inputText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }

                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .padding(.horizontal)
                                    Spacer()
                                }
                                .id("loading")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Error message
                if let error = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Chiudi") {
                            errorMessage = nil
                        }
                        .font(.caption)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                }

                // Quick suggestions (when empty)
                if messages.isEmpty && !isLoading {
                    QuickSuggestionsView { suggestion in
                        inputText = suggestion
                        sendMessage()
                    }
                }

                // Input area
                HStack(spacing: 12) {
                    TextField("Chiedi al sommelier...", text: $inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(20)
                        .focused($isInputFocused)
                        .lineLimit(1...5)

                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .foregroundColor(inputText.isEmpty ? .gray : .purple)
                    }
                    .disabled(inputText.isEmpty || isLoading)
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationTitle("Sommelier AI")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        clearChat()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(messages.isEmpty)
                }
            }
        }
    }

    private func sendMessage() {
        guard !inputText.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: inputText)
        modelContext.insert(userMessage)
        try? modelContext.save()

        let messageText = inputText
        inputText = ""
        isInputFocused = false

        Task {
            await getAIResponse(for: messageText)
        }
    }

    private func getAIResponse(for message: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await OpenAIService.shared.chatWithSommelier(
                message: message,
                history: Array(messages),
                wines: wines,
                bottles: bottles
            )

            let assistantMessage = ChatMessage(role: .assistant, content: response)
            modelContext.insert(assistantMessage)
            try? modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func clearChat() {
        for message in messages {
            modelContext.delete(message)
        }
        try? modelContext.save()
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(isUser ? Color.purple : Color(.secondarySystemBackground))
                    .foregroundColor(isUser ? .white : .primary)
                    .cornerRadius(16)

                Text(formatTime(message.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct QuickSuggestionsView: View {
    let onSelect: (String) -> Void

    let suggestions = [
        "Cosa mi consigli per una cena di pesce?",
        "Ho uno Chardonnay, con cosa lo abbino?",
        "Qual è il vino migliore nella mia cantina?",
        "Suggeriscimi un vino rosso corposo"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggerimenti")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            onSelect(suggestion)
                        } label: {
                            Text(suggestion)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.tertiarySystemBackground))
                                .cornerRadius(16)
                        }
                        .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ChatView()
        .modelContainer(for: [ChatMessage.self, Wine.self, Bottle.self, AppSettings.self], inMemory: true)
}
