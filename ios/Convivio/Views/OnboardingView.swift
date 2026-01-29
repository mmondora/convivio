import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var languageManager = LanguageManager.shared
    @Bindable var settings: AppSettings

    @State private var apiKey = ""
    @State private var showApiKeyField = false
    @State private var isValidating = false
    @State private var validationError: String?

    let onComplete: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Logo/Icon
                Image(systemName: "wineglass.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Title
                VStack(spacing: 8) {
                    Text("Convivio")
                        .font(.largeTitle.bold())

                    Text(L10n.welcomeSubtitle)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if showApiKeyField {
                    apiKeySection
                } else {
                    welcomeSection
                }

                Spacer()

                // Language selector at bottom
                languageSelector
            }
            .padding()
            .navigationBarHidden(true)
        }
    }

    // MARK: - Welcome Section

    private var welcomeSection: some View {
        VStack(spacing: 20) {
            // Features
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "camera.viewfinder",
                    title: featureTitle1,
                    description: featureDesc1
                )

                FeatureRow(
                    icon: "sparkles",
                    title: featureTitle2,
                    description: featureDesc2
                )

                FeatureRow(
                    icon: "bubble.left.and.bubble.right",
                    title: featureTitle3,
                    description: featureDesc3
                )
            }
            .padding()

            Button {
                withAnimation {
                    showApiKeyField = true
                }
            } label: {
                Text(L10n.getStarted)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - API Key Section

    private var apiKeySection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.apiKeyRequired)
                    .font(.headline)

                Text(L10n.apiKeyInstructions)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 12) {
                SecureField(L10n.apiKeyPlaceholder, text: $apiKey)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                if let error = validationError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Button {
                    Task {
                        await validateAndSaveApiKey()
                    }
                } label: {
                    HStack {
                        if isValidating {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(L10n.enterApiKey)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(apiKey.isEmpty ? Color.gray : Color.purple)
                    .cornerRadius(12)
                }
                .disabled(apiKey.isEmpty || isValidating)

                Button {
                    completeOnboarding()
                } label: {
                    Text(L10n.skipForNow)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Language Selector

    private var languageSelector: some View {
        HStack(spacing: 12) {
            ForEach(AppLanguage.allCases) { language in
                Button {
                    languageManager.setLanguage(language)
                } label: {
                    Text(language.flag)
                        .font(.title2)
                        .padding(8)
                        .background(
                            languageManager.currentLanguage == language
                                ? Color.purple.opacity(0.2)
                                : Color.clear
                        )
                        .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Feature Texts (localized)

    private var featureTitle1: String {
        switch languageManager.currentLanguage {
        case .italian: return "Scansiona etichette"
        case .english: return "Scan labels"
        case .german: return "Etiketten scannen"
        case .french: return "Scanner les étiquettes"
        }
    }

    private var featureDesc1: String {
        switch languageManager.currentLanguage {
        case .italian: return "Aggiungi vini alla tua cantina con una foto"
        case .english: return "Add wines to your cellar with a photo"
        case .german: return "Fügen Sie Weine mit einem Foto hinzu"
        case .french: return "Ajoutez des vins avec une photo"
        }
    }

    private var featureTitle2: String {
        switch languageManager.currentLanguage {
        case .italian: return "Menu intelligente"
        case .english: return "Smart menu"
        case .german: return "Intelligentes Menü"
        case .french: return "Menu intelligent"
        }
    }

    private var featureDesc2: String {
        switch languageManager.currentLanguage {
        case .italian: return "Genera menu con abbinamenti vino perfetti"
        case .english: return "Generate menus with perfect wine pairings"
        case .german: return "Erstellen Sie Menüs mit perfekten Weinempfehlungen"
        case .french: return "Générez des menus avec des accords parfaits"
        }
    }

    private var featureTitle3: String {
        switch languageManager.currentLanguage {
        case .italian: return "Sommelier AI"
        case .english: return "AI Sommelier"
        case .german: return "KI-Sommelier"
        case .french: return "Sommelier IA"
        }
    }

    private var featureDesc3: String {
        switch languageManager.currentLanguage {
        case .italian: return "Chiedi consigli al tuo sommelier personale"
        case .english: return "Ask your personal sommelier for advice"
        case .german: return "Fragen Sie Ihren persönlichen Sommelier"
        case .french: return "Demandez conseil à votre sommelier personnel"
        }
    }

    // MARK: - Actions

    private func validateAndSaveApiKey() async {
        isValidating = true
        validationError = nil

        // Basic validation
        guard apiKey.hasPrefix("sk-") else {
            validationError = languageManager.currentLanguage == .italian
                ? "La chiave deve iniziare con 'sk-'"
                : "Key must start with 'sk-'"
            isValidating = false
            return
        }

        // Save and complete
        settings.openAIApiKey = apiKey
        settings.updatedAt = Date()
        try? modelContext.save()

        await OpenAIService.shared.setApiKey(apiKey)

        isValidating = false
        completeOnboarding()
    }

    private func completeOnboarding() {
        settings.preferredLanguage = languageManager.currentLanguage.rawValue
        settings.updatedAt = Date()
        try? modelContext.save()
        onComplete()
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.purple)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    OnboardingView(settings: AppSettings()) {}
        .modelContainer(for: AppSettings.self, inMemory: true)
}
