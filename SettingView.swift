import SwiftUI
import Combine
import FirebaseAuth

// Manages the theme state using UserDefaults
class ThemeManager: ObservableObject {
    @AppStorage("selectedTheme") var selectedTheme: ThemeOption = .auto
}

// Defines the available theme options
enum ThemeOption: String, CaseIterable, Identifiable {
    case auto, light, dark, animated
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .auto: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        case .animated: return "Animated"
        }
    }
}

// A reusable view for the animated gradient background
struct AnimatedBackgroundView: View {
    @State private var start = UnitPoint(x: 0, y: -2)
    @State private var end = UnitPoint(x: 4, y: 0)
    let timer = Timer.publish(every: 1, on: .main, in: .default).autoconnect()

    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [.blue, .purple, .pink, .orange]),
            startPoint: start,
            endPoint: end
        )
        .animation(Animation.easeInOut(duration: 6).repeatForever(), value: start)
        .onReceive(timer) { _ in
            self.start = UnitPoint(x: 4, y: 0)
            self.end = UnitPoint(x: 0, y: 2)
            self.start = UnitPoint(x: -4, y: 20)
            self.start = UnitPoint(x: 4, y: 0)
        }
        .blur(radius: 100)
        .ignoresSafeArea()
    }
}

// The main settings view
struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $themeManager.selectedTheme) {
                        ForEach(ThemeOption.allCases) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                }
                
                Section {
                    Button("Sign Out", role: .destructive) {
                        signOut()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func signOut() {
        do {
            try Auth.auth().signOut()
        } catch let signOutError as NSError {
            print("Error signing out: %@", signOutError)
        }
    }
}

