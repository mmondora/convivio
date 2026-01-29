import SwiftUI

struct ChatView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var firebaseService: FirebaseService

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var scrollToBottom = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Welcome message
                            if messages.isEmpty && !isLoading {
                                WelcomeMessage()
                            }

                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }

                            if isLoading {
                                HStack {
                                    TypingIndicator()
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .id("typing")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        withAnimation {
                            proxy.scrollTo(messages.last?.id ?? "typing", anchor: .bottom)
                        }
                    }
                    .onChange(of: isLoading) { _, loading in
                        if loading {
                            withAnimation {
                                proxy.scrollTo("typing", anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                // Input bar
                HStack(spacing: 12) {
                    TextField("Chiedi al sommelier...", text: $inputText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)

                    Button {
                        Task { await sendMessage() }
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
                        messages = []
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(messages.isEmpty)
                }
            }
        }
    }

    private func sendMessage() async {
        guard let userId = authManager.currentUser?.uid,
              let cellarId = firebaseService.currentCellar?.id else { return }

        let userMessage = ChatMessage(
            userId: userId,
            cellarId: cellarId,
            role: .user,
            content: inputText,
            createdAt: .init(date: Date())
        )

        messages.append(userMessage)
        let messageText = inputText
        inputText = ""
        isLoading = true

        do {
            let response = try await firebaseService.chatWithSommelier(
                message: messageText,
                userId: userId,
                cellarId: cellarId
            )
            messages.append(response)
        } catch {
            let errorMessage = ChatMessage(
                userId: "system",
                cellarId: cellarId,
                role: .assistant,
                content: "Mi dispiace, si è verificato un errore. Riprova.",
                createdAt: .init(date: Date())
            )
            messages.append(errorMessage)
        }

        isLoading = false
    }
}

struct WelcomeMessage: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wineglass.fill")
                .font(.system(size: 60))
                .foregroundStyle(.purple.gradient)

            Text("Ciao! Sono il tuo sommelier AI")
                .font(.title2.bold())

            Text("Posso aiutarti a scoprire i vini nella tua cantina, suggerirti abbinamenti, e rispondere alle tue domande sul vino.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                SuggestionChip(text: "Quali vini ho in cantina?")
                SuggestionChip(text: "Cosa abbino a una bistecca?")
                SuggestionChip(text: "Consiglia un vino per stasera")
            }
        }
        .padding()
    }
}

struct SuggestionChip: View {
    let text: String

    var body: some View {
        HStack {
            Image(systemName: "lightbulb")
                .foregroundColor(.orange)
            Text(text)
                .font(.subheadline)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(20)
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(isUser ? Color.purple : Color(.secondarySystemBackground))
                    .foregroundColor(isUser ? .white : .primary)
                    .cornerRadius(20)

                Text(formatTime(message.createdAt.dateValue()))
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

struct TypingIndicator: View {
    @State private var animationPhase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.4)
                            .repeatForever()
                            .delay(Double(index) * 0.15),
                        value: animationPhase
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
        .onAppear {
            animationPhase = 2
        }
    }
}

#Preview {
    ChatView()
        .environmentObject(AuthManager.shared)
        .environmentObject(FirebaseService.shared)
}
