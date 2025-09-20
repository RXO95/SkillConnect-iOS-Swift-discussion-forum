import SwiftUI
import Firebase

@main
struct SkillConnectApp: App {
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            MainView() 
        }
    }
}
