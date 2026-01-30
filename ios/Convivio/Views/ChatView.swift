import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \ChatMessage.createdAt) private var messages: [ChatMessage]
    @Query private var wines: [Wine]
    @Query(filter: #Predicate<Bottle> { $0.quantity > 0 }) private var bottles: [Bottle]
    @Query private var settings: [AppSettings]

    @State private var inputText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var isInputFocused: Bool

    // Max width for content on iPad
    private var maxContentWidth: CGFloat? {
        horizontalSizeClass == .regular ? 800 : nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubbleWithSuggestions(
                                    message: message,
                                    wines: wines,
                                    bottles: bottles
                                )
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
                        .frame(maxWidth: maxContentWidth)
                        .frame(maxWidth: .infinity)
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
                    .frame(maxWidth: maxContentWidth)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground))
                }

                // Quick suggestions (when empty)
                if messages.isEmpty && !isLoading {
                    QuickSuggestionsView { suggestion in
                        inputText = suggestion
                        sendMessage()
                    }
                    .frame(maxWidth: maxContentWidth)
                    .frame(maxWidth: .infinity)
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
                .frame(maxWidth: maxContentWidth)
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
            }
            .navigationTitle(L10n.sommelier)
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

// MARK: - Message Bubble with Suggestions

struct MessageBubbleWithSuggestions: View {
    let message: ChatMessage
    let wines: [Wine]
    let bottles: [Bottle]

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var isUser: Bool { message.role == .user }

    // Parse on demand - only for assistant messages
    private var parsedResponse: SommelierResponseParser.ParsedResponse? {
        guard !isUser else { return nil }
        return SommelierResponseParser.parse(message.content)
    }

    // Adaptive spacing based on device size
    private var minSpacing: CGFloat {
        horizontalSizeClass == .regular ? 200 : 60
    }

    // Max width for message content on iPad
    private var maxMessageWidth: CGFloat? {
        horizontalSizeClass == .regular ? 500 : nil
    }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: minSpacing) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
                // Message text
                Text(displayText)
                    .padding(12)
                    .background(isUser ? Color.purple : Color(.secondarySystemBackground))
                    .foregroundColor(isUser ? .white : .primary)
                    .cornerRadius(16)
                    .frame(maxWidth: maxMessageWidth, alignment: isUser ? .trailing : .leading)

                // Wine suggestions (only for assistant messages)
                if let parsed = parsedResponse, !parsed.suggestions.isEmpty {
                    WineSuggestionsSection(
                        suggestions: parsed.suggestions,
                        wines: wines,
                        bottles: bottles
                    )
                    .frame(maxWidth: maxMessageWidth, alignment: .leading)
                }

                Text(formatTime(message.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if !isUser { Spacer(minLength: minSpacing) }
        }
    }

    private var displayText: String {
        if let parsed = parsedResponse {
            return parsed.text
        }
        return message.content
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Wine Suggestions Section

struct WineSuggestionsSection: View {
    let suggestions: [SommelierWineSuggestion]
    let wines: [Wine]
    let bottles: [Bottle]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "wineglass.fill")
                    .font(.caption)
                    .foregroundColor(.purple)
                Text("Vini suggeriti")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }

            ForEach(suggestions) { suggestion in
                WineSuggestionCard(
                    suggestion: suggestion,
                    wines: wines,
                    bottles: bottles
                )
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Wine Suggestion Card

struct WineSuggestionCard: View {
    let suggestion: SommelierWineSuggestion
    let wines: [Wine]
    let bottles: [Bottle]

    @State private var matchResult: WineMatchingService.MatchResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Wine name and badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.displayName)
                        .font(.subheadline.bold())

                    if let reason = suggestion.reason {
                        Text(reason)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                // Cellar status badge
                cellarStatusBadge
            }

            // If matched, show details and navigation
            if let match = matchResult?.match {
                NavigationLink {
                    BottleDetailView(bottle: match.bottle)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: match.wine.type.icon.isEmpty ? "wineglass" : "wineglass.fill")
                            .foregroundColor(.purple)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Vai alla scheda vino")
                                .font(.caption.bold())
                            Text(match.matchReason)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            // Show alternatives if no direct match
            if matchResult?.match == nil, let alternatives = matchResult?.alternatives, !alternatives.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Alternative dalla tua cantina:")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    ForEach(alternatives, id: \.wine.id) { alt in
                        NavigationLink {
                            BottleDetailView(bottle: alt.bottle)
                        } label: {
                            HStack {
                                Text(alt.wine.type.icon)
                                    .font(.caption)
                                Text(alt.wine.displayName)
                                    .font(.caption)
                                Spacer()
                                Text("\(alt.bottle.quantity)")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green)
                                    .clipShape(Capsule())
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(6)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .onAppear {
            matchResult = WineMatchingService.match(
                suggestion: suggestion,
                wines: wines,
                bottles: bottles
            )
        }
    }

    @ViewBuilder
    private var cellarStatusBadge: some View {
        if let match = matchResult?.match {
            // Wine is in cellar
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    Text("In cantina")
                        .font(.caption.bold())
                }
                .foregroundColor(.green)

                Text("\(match.totalQuantity) bottigli\(match.totalQuantity == 1 ? "a" : "e")")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if let location = match.location {
                    Text(location)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.15))
            .cornerRadius(8)
        } else {
            // Wine to purchase
            HStack(spacing: 4) {
                Image(systemName: "cart")
                    .font(.caption)
                Text("Da acquistare")
                    .font(.caption.bold())
            }
            .foregroundColor(.blue)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.15))
            .cornerRadius(8)
        }
    }
}

// MARK: - Quick Suggestions View

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
