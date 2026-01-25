//
//  ConvivioApp.swift
//  Convivio
//
//  App entry point con Firebase initialization e navigation setup
//

import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct ConvivioApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var appState = AppState.shared

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isLoading {
                    SplashView()
                } else if authManager.isAuthenticated {
                    MainTabView()
                        .environmentObject(authManager)
                        .environmentObject(appState)
                } else {
                    AuthenticationView()
                        .environmentObject(authManager)
                }
            }
            .animation(.easeInOut, value: authManager.isAuthenticated)
        }
    }
}

// MARK: - App State

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var selectedTab: Tab = .cellar
    @Published var showingScanner = false
    @Published var currentCellarId: String?
    
    enum Tab: Int, CaseIterable {
        case cellar = 0
        case scan = 1
        case dinner = 2
        case ai = 3
        case profile = 4
        
        var title: String {
            switch self {
            case .cellar: return "Cantina"
            case .scan: return "Scan"
            case .dinner: return "Cena"
            case .ai: return "AI"
            case .profile: return "Profilo"
            }
        }
        
        var icon: String {
            switch self {
            case .cellar: return "wineglass"
            case .scan: return "camera"
            case .dinner: return "fork.knife"
            case .ai: return "sparkles"
            case .profile: return "person.circle"
            }
        }
    }
}

// MARK: - Splash View

struct SplashView: View {
    var body: some View {
        ZStack {
            Color("Background")
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "wineglass.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Convivio")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                ProgressView()
                    .tint(.primary)
            }
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView(selection: $appState.selectedTab) {
            CellarView()
                .tabItem {
                    Label(AppState.Tab.cellar.title, systemImage: AppState.Tab.cellar.icon)
                }
                .tag(AppState.Tab.cellar)
            
            ScanView()
                .tabItem {
                    Label(AppState.Tab.scan.title, systemImage: AppState.Tab.scan.icon)
                }
                .tag(AppState.Tab.scan)
            
            DinnerListView()
                .tabItem {
                    Label(AppState.Tab.dinner.title, systemImage: AppState.Tab.dinner.icon)
                }
                .tag(AppState.Tab.dinner)
            
            ChatView()
                .tabItem {
                    Label(AppState.Tab.ai.title, systemImage: AppState.Tab.ai.icon)
                }
                .tag(AppState.Tab.ai)
            
            ProfileView()
                .tabItem {
                    Label(AppState.Tab.profile.title, systemImage: AppState.Tab.profile.icon)
                }
                .tag(AppState.Tab.profile)
        }
        .tint(.primary)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState.shared)
        .environmentObject(AuthManager.shared)
}
