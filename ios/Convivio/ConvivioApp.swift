import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

@main
struct ConvivioApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var firebaseService = FirebaseService.shared

    init() {
        FirebaseApp.configure()

        #if targetEnvironment(simulator)
        // Always connect to emulators in simulator
        let settings = Firestore.firestore().settings
        settings.host = "127.0.0.1:8080"
        settings.cacheSettings = MemoryCacheSettings()
        settings.isSSLEnabled = false
        Firestore.firestore().settings = settings

        Auth.auth().useEmulator(withHost: "127.0.0.1", port: 9099)
        Functions.functions(region: "europe-west1").useEmulator(withHost: "127.0.0.1", port: 5001)

        print("🔧 Firebase Emulators configured: Auth=9099, Firestore=8080, Functions=5001")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(firebaseService)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var firebaseService: FirebaseService

    var body: some View {
        Group {
            if authManager.isLoading {
                LoadingView()
            } else if authManager.isAuthenticated {
                MainTabView()
                    .onAppear {
                        if let userId = authManager.currentUser?.uid {
                            firebaseService.loadCellars(for: userId)
                        }
                    }
            } else {
                LoadingView()
                    .task {
                        try? await authManager.signInAnonymously()
                    }
            }
        }
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Caricamento...")
                .foregroundColor(.secondary)
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var firebaseService: FirebaseService

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

            DinnerListView()
                .tabItem {
                    Label("Cene", systemImage: "fork.knife")
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
