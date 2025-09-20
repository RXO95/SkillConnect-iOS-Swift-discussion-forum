import SwiftUI
import Firebase
import FirebaseAuth
import Combine

class AuthViewModel: ObservableObject {
    @Published var isSignedIn = false

    private var handle: AuthStateDidChangeListenerHandle?

    init() {
       
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.isSignedIn = (user != nil)
        }
    }

    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}


struct MainView: View {

    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
      
        if authViewModel.isSignedIn {
            ContentView()
        } else {
            LoginView()
        }
    }
}
