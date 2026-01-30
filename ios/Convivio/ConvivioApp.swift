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
                SchedaAIS.self,
                StorageArea.self,
                StorageContainer.self,
                Cellar.self,
                DishProposal.self,
                Vote.self,
                Comment.self
            ])

            // Configure CloudKit sync for production, local-only for development
            #if DEBUG
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            #else
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.mikesoft.convivio")
            )
            #endif

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
                .onOpenURL { url in
                    // Handle CloudKit share URLs
                    handleIncomingURL(url)
                }
        }
        .modelContainer(modelContainer)
    }

    private func handleIncomingURL(_ url: URL) {
        // CloudKit share URLs will be handled by SharingService in Phase 2
        print("Received URL: \(url)")
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

        // Check iCloud status and run migration if needed
        await CloudKitService.shared.checkiCloudStatus()
        if MigrationService.shared.needsMigration {
            try? await MigrationService.shared.migrateLocalDataToCloudKit(context: modelContext)
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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
        .modifier(AdaptiveTabStyle())
        .tint(.purple)
    }
}

// MARK: - Adaptive Tab Style Modifier

struct AdaptiveTabStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.tabViewStyle(.sidebarAdaptable)
        } else {
            content
        }
    }
}

// MARK: - Adaptive Layout Helpers

/// Container that constrains content width on iPad for better readability
struct AdaptiveFormContainer<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if horizontalSizeClass == .regular {
            content
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
        } else {
            content
        }
    }
}

/// Returns adaptive padding based on device size class
struct AdaptiveLayout {
    static func horizontalPadding(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? 40 : 16
    }

    static func cardMaxWidth(for sizeClass: UserInterfaceSizeClass?) -> CGFloat? {
        sizeClass == .regular ? 600 : nil
    }

    static func messageMaxWidth(for sizeClass: UserInterfaceSizeClass?, screenWidth: CGFloat) -> CGFloat {
        if sizeClass == .regular {
            return min(500, screenWidth * 0.6)
        } else {
            return screenWidth * 0.75
        }
    }
}
