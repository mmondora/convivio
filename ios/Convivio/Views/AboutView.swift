import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    // Max width for content on iPad
    private var maxContentWidth: CGFloat? {
        horizontalSizeClass == .regular ? 600 : nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                headerSection

                // Developer Section
                developerSection

                // Story Section
                storySection

                // Release Notes Section
                releaseNotesSection

                // Contact Section
                contactSection

                // Privacy Section
                privacySection

                // Footer
                footerSection
            }
            .padding()
            .frame(maxWidth: maxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // App Icon - using a styled wine glass icon
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "722F37"), Color(hex: "4A1C24")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)

                Image(systemName: "wineglass.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.white)
            }

            VStack(spacing: 4) {
                Text("Convivio")
                    .font(.title.bold())

                Text("Versione \(appVersion) (\(buildNumber))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Developer Section

    private var developerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "person.fill")
                    .font(.title3)
                    .foregroundColor(.purple)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("mikesoft")
                        .font(.headline)

                    Text("Codice, vino e buone vibrazioni.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Text("Sviluppo app per passione, una bottiglia alla volta.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .italic()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 44)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Story Section

    private var storySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "book.fill")
                    .font(.title3)
                    .foregroundColor(Color(hex: "722F37"))

                Text("La storia")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Convivio nasce da due cose semplici: la voglia di sperimentare con il codice e una cantina che aveva bisogno di ordine. Nessun business plan, nessun pitch deck — solo un'idea, un po' di tempo libero e tanta curiosità.")

                Text("L'app è pensata per chi ama il vino senza prendersi troppo sul serio, vuole sapere cosa ha in cantina e magari farsi aiutare a scegliere la bottiglia giusta per la prossima cena.")

                Text("Se Convivio ti è utile, sono contento. Se hai suggerimenti, ancora di più.")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .lineSpacing(4)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Release Notes Section

    private var releaseNotesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundColor(.purple)

                Text("Novità v\(appVersion)")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 12) {
                ReleaseNoteItem(
                    icon: "🚀",
                    text: "Performance ottimizzate con paginazione liste"
                )
                ReleaseNoteItem(
                    icon: "🤖",
                    text: "Selezione modello AI intelligente per risposte veloci"
                )
                ReleaseNoteItem(
                    icon: "💾",
                    text: "Cache risposte API per evitare chiamate ridondanti"
                )
                ReleaseNoteItem(
                    icon: "📊",
                    text: "Monitor performance nel pannello Debug"
                )
                ReleaseNoteItem(
                    icon: "⏳",
                    text: "Nuovi componenti UX per stati di caricamento"
                )
            }

            NavigationLink {
                ReleaseNotesView()
            } label: {
                HStack {
                    Text("Tutte le note di rilascio")
                        .font(.subheadline)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .foregroundColor(.purple)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Contact Section

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "envelope.fill")
                    .font(.title3)
                    .foregroundColor(Color(hex: "722F37"))

                Text("Contatti")
                    .font(.headline)
            }

            Link(destination: URL(string: "mailto:michele@mondora.com")!) {
                HStack {
                    Text("📧")
                    Text("michele@mondora.com")
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                }
                .foregroundColor(.primary)
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .font(.title3)
                    .foregroundColor(.green)

                Text("Privacy")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Convivio utilizza OpenAI per le funzionalità di sommelier AI e generazione menu. I dati vengono inviati ai server OpenAI tramite la tua API key personale, sulla tua sottoscrizione.")

                Text("Nessun dato transita su server dello sviluppatore. Tutti i dati della cantina restano sul tuo dispositivo.")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .lineSpacing(4)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Text("Sviluppato in Italia")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Text("🇮🇹")
            }

            Text("Versione \(appVersion) • 2026")
                .font(.caption)
                .foregroundColor(Color.secondary.opacity(0.7))

            // Decorative wine glass
            Image(systemName: "wineglass")
                .font(.title2)
                .foregroundColor(Color(hex: "722F37").opacity(0.3))
                .padding(.top, 8)
        }
        .padding(.vertical, 20)
    }
}

// MARK: - Release Note Item

struct ReleaseNoteItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(icon)
                .font(.body)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
