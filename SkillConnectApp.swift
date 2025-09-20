import SwiftUI
import Firebase

@main
struct SkillConnectApp: App {
    @StateObject private var themeManager = ThemeManager()

    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if themeManager.selectedTheme == .animated {
                    AnimatedBackgroundView()
                }
                
                MainView()
                    .environmentObject(themeManager)
                    .preferredColorScheme(getPreferredColorScheme())
            }
        }
    }
    
    func getPreferredColorScheme() -> ColorScheme? {
        switch themeManager.selectedTheme {
        case .light:
            return .light
        case .dark:
            return .dark
        default:
            return nil
        }
    }
}

