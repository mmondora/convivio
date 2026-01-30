import SwiftUI
import SwiftData
import UserNotifications

// MARK: - App Delegate for Notifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner, sound, and badge even when app is open
        completionHandler([.banner, .sound, .badge])
    }

    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("📬 Notification tapped: \(userInfo)")

        // Handle actions based on category
        if let action = userInfo["action"] as? String {
            switch action {
            case "putInFridge", "takeOut":
                // Could navigate to wine details
                print("Wine reminder action: \(action)")
            case "unloadBottles":
                // Could navigate to bottle unload view
                print("Bottle unload reminder")
            default:
                break
            }
        }

        completionHandler()
    }
}

@main
struct ConvivioApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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
    @StateObject private var languageManager = LanguageManager.shared

    @State private var showOnboarding = false
    @State private var isReady = false

    var body: some View {
        Group {
            if !isReady {
                // Loading state
                ProgressView()
            } else if showOnboarding, let appSettings = settings.first {
                OnboardingView(settings: appSettings) {
                    withAnimation {
                        showOnboarding = false
                    }
                }
                .environmentObject(languageManager)
            } else {
                MainTabView()
                    .environmentObject(languageManager)
            }
        }
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

        // Small delay to ensure settings are loaded
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Sync language manager with saved settings
        if let savedLanguage = settings.first?.preferredLanguage,
           let language = AppLanguage(rawValue: savedLanguage) {
            languageManager.setLanguage(language)
        }

        // Load API key if it exists
        if let openAIKey = settings.first?.openAIApiKey, !openAIKey.isEmpty {
            await OpenAIService.shared.setApiKey(openAIKey)
            showOnboarding = false
        } else {
            // Show onboarding if no API key
            showOnboarding = true
        }

        isReady = true
    }
}

struct MainTabView: View {
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        TabView {
            CellarView()
                .tabItem {
                    Label(L10n.cellar, systemImage: "wineglass")
                }

            ScanView()
                .tabItem {
                    Label(L10n.scan, systemImage: "camera")
                }

            FoodView()
                .tabItem {
                    Label(L10n.convivio, systemImage: "fork.knife")
                }

            ChatView()
                .tabItem {
                    Label(L10n.sommelier, systemImage: "bubble.left.and.bubble.right")
                }

            ProfileView()
                .tabItem {
                    Label(L10n.profile, systemImage: "person.circle")
                }
        }
        .tint(.purple)
    }
}
