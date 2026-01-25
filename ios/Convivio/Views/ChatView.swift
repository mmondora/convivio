//
//  ChatView.swift
//  Convivio
//
//  Chat conversazionale con AI Sommelier
//

import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            if viewModel.isLoading {
                                TypingIndicator()
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Quick suggestions
                if viewModel.messages.isEmpty {
                    quickSuggestions
                }
                
                // Input
                inputBar
            }
            .navigationTitle("AI Sommelier")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.startNewConversation()
                    } label: {
                        Image(systemName: "plus.message")
                    }
                }
            }
        }
    }
    
    // MARK: - Quick Suggestions
    
    private var quickSuggestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                SuggestionChip(text: "Cosa ho in cantina?") {
                    viewModel.sendMessage("Cosa ho in cantina?")
                }
                
                SuggestionChip(text: "Consiglia un rosso per stasera") {
                    viewModel.sendMessage("Consiglia un rosso per stasera")
                }
                
                SuggestionChip(text: "Dove trovo il Barolo?") {
                    viewModel.sendMessage("Dove trovo il Barolo?")
                }
                
                SuggestionChip(text: "Abbinamento per pesce") {
                    viewModel.sendMessage("Che vino abbino al pesce?")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Input Bar
    
    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Chiedi al sommelier...", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .focused($isInputFocused)
            
            Button {
                viewModel.sendMessage(viewModel.inputText)
                viewModel.inputText = ""
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessageUI
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 60)
            } else {
                // AI avatar
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.purple)
                    .frame(width: 28, height: 28)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(Circle())
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(message.isUser ? Color.accentColor : Color(.secondarySystemBackground))
                    .foregroundStyle(message.isUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                
                // Wine references
                if !message.wineReferences.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(message.wineReferences) { wine in
                            WineReferenceChip(wine: wine)
                        }
                    }
                }
            }
            
            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Wine Reference Chip

struct WineReferenceChip: View {
    let wine: Wine
    
    var body: some View {
        HStack(spacing: 6) {
            Text(wine.type.icon)
            Text(wine.displayName)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Suggestion Chip

struct SuggestionChip: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemBackground))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { animating = true }
    }
}

// MARK: - UI Models

struct ChatMessageUI: Identifiable {
    let id: String
    let content: String
    let isUser: Bool
    let wineReferences: [Wine]
    let timestamp: Date
}

// MARK: - View Model

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessageUI] = []
    @Published var inputText = ""
    @Published var isLoading = false
    @Published var conversationId: String?
    @Published var error: String?

    private let firebase = FirebaseService.shared
    private var wineCache: [String: Wine] = [:]

    func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Add user message
        let userMessage = ChatMessageUI(
            id: UUID().uuidString,
            content: trimmed,
            isUser: true,
            wineReferences: [],
            timestamp: Date()
        )
        messages.append(userMessage)

        isLoading = true

        Task {
            do {
                // Create conversation if needed
                if conversationId == nil {
                    conversationId = try await firebase.createConversation()
                }

                // Save user message to Firestore
                if let convId = conversationId {
                    let chatMessage = ChatMessage(
                        id: nil,
                        role: .user,
                        content: trimmed,
                        createdAt: nil
                    )
                    try await firebase.addMessage(chatMessage, to: convId)
                }

                // Call Cloud Function
                let response = try await firebase.chatWithSommelier(
                    message: trimmed,
                    conversationId: conversationId,
                    cellarContext: true
                )

                // Update conversation ID if new
                if let newConvId = response.conversationId {
                    conversationId = newConvId
                }

                // Fetch referenced wines
                var wines: [Wine] = []
                for wineId in response.wineIds {
                    if let cachedWine = wineCache[wineId] {
                        wines.append(cachedWine)
                    } else {
                        // Fetch wine from Firestore
                        let allWines = try await firebase.getWines()
                        if let wine = allWines.first(where: { $0.id == wineId }) {
                            wineCache[wineId] = wine
                            wines.append(wine)
                        }
                    }
                }

                // Save assistant message
                if let convId = conversationId {
                    let assistantMessage = ChatMessage(
                        id: nil,
                        role: .assistant,
                        content: response.message,
                        createdAt: nil
                    )
                    try await firebase.addMessage(assistantMessage, to: convId)
                }

                // Add to UI
                let uiMessage = ChatMessageUI(
                    id: UUID().uuidString,
                    content: response.message,
                    isUser: false,
                    wineReferences: wines,
                    timestamp: Date()
                )
                messages.append(uiMessage)

            } catch {
                self.error = error.localizedDescription

                // Add error message to UI
                let errorMessage = ChatMessageUI(
                    id: UUID().uuidString,
                    content: "Mi dispiace, c'è stato un errore. Riprova.",
                    isUser: false,
                    wineReferences: [],
                    timestamp: Date()
                )
                messages.append(errorMessage)
            }

            isLoading = false
        }
    }

    func startNewConversation() {
        messages = []
        conversationId = nil
    }

    func loadConversation(_ convId: String) async {
        do {
            conversationId = convId
            let chatMessages = try await firebase.getMessages(conversationId: convId)

            messages = chatMessages.map { msg in
                ChatMessageUI(
                    id: msg.id ?? UUID().uuidString,
                    content: msg.content,
                    isUser: msg.role == .user,
                    wineReferences: [],
                    timestamp: msg.createdAt?.dateValue() ?? Date()
                )
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    ChatView()
}
