import SwiftUI
import SwiftData

@main
struct ConvivioApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                Wine.self,
                Bottle.self,
                DinnerEvent.self,
                ChatMessage.self,
                AppSettings.self,
                QuickRating.self,
                SchedaAIS.self
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]

    var body: some View {
        MainTabView()
            .task {
                await setupApp()
            }
    }

    private func setupApp() async {
        // Create default settings if needed
        if settings.isEmpty {
            let defaultSettings = AppSettings()
            modelContext.insert(defaultSettings)
            try? modelContext.save()
        }

        // Load API key if it exists
        if let openAIKey = settings.first?.openAIApiKey {
            await OpenAIService.shared.setApiKey(openAIKey)
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            CellarView()
                .tabItem {
                    Label("Cantina", systemImage: "wineglass")
                }

            ScanView()
                .tabItem {
                    Label("Scansiona", systemImage: "camera")
                }

            FoodView()
                .tabItem {
                    Label("Convivio", systemImage: "fork.knife")
                }

            ChatView()
                .tabItem {
                    Label("Sommelier", systemImage: "bubble.left.and.bubble.right")
                }

            ProfileView()
                .tabItem {
                    Label("Profilo", systemImage: "person.circle")
                }
        }
        .tint(.purple)
    }
}
