import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import Combine

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var userIsLoggedIn = false
    @State private var isSigningUp = false
    @State private var errorMessage: String?
    @State private var showingPasswordResetAlert = false

    @State private var start = UnitPoint(x: 0, y: -2)
    @State private var end = UnitPoint(x: 4, y: 0)
    
    let timer = Timer.publish(every: 1, on: .main, in: .default).autoconnect()

    var body: some View {
        ZStack {
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
            .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Text("SkillConnect")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.bottom, 30)
                
                Text(isSigningUp ? "Create an Account" : "Welcome Back")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.8))

                VStack(spacing: 15) {
                    if isSigningUp {
                        TextField("Username", text: $username)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(15)
                            .foregroundColor(.white)
                            .tint(.white)
                            .autocapitalization(.none)
                    }

                    TextField(isSigningUp ? "Email" : "Email or Username", text: $email)
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(15)
                        .foregroundColor(.white)
                        .tint(.white)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                
                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(15)
                        .foregroundColor(.white)
                        .tint(.white)
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding(.top, 5)
                }

                Button(action: {
                    isSigningUp ? signUp() : login()
                }) {
                    Text(isSigningUp ? "Sign Up" : "Log In")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.9))
                        .foregroundColor(.blue.opacity(0.8))
                        .cornerRadius(15)
                        .shadow(radius: 5)
                }
                .padding(.top)
                
                if !isSigningUp {
                    Button(action: {
                        forgotPassword()
                    }) {
                        Text("Forgot Password?")
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.top, 5)
                }

                Button(action: {
                    isSigningUp.toggle()
                    errorMessage = nil
                    email = ""
                    password = ""
                    username = ""
                }) {
                    Text(isSigningUp ? "Already have an account? Log In" : "Don't have an account? Sign Up")
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 30)
        }
        .alert("Password Reset", isPresented: $showingPasswordResetAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("A password reset link has been sent to your email address.")
        }
    }

    func login() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else {
            self.errorMessage = "Email/Username and Password cannot be empty."
            return
        }
        
        if trimmedEmail.contains("@") {
            signInWith(email: trimmedEmail, password: trimmedPassword)
        } else {
            let db = Firestore.firestore()
            db.collection("users").whereField("username", isEqualTo: trimmedEmail.lowercased()).getDocuments { (snapshot, error) in
                if let error = error {
                    self.errorMessage = "Error finding user: \(error.localizedDescription)"
                    return
                }
                
                guard let documents = snapshot?.documents, documents.count == 1, let userData = documents.first?.data() else {
                    self.errorMessage = "Username not found."
                    return
                }
                
                if let userEmail = userData["email"] as? String {
                    self.signInWith(email: userEmail, password: trimmedPassword)
                } else {
                    self.errorMessage = "Could not retrieve email for this user."
                }
            }
        }
    }
    
    func signInWith(email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                self.errorMessage = error.localizedDescription
            } else {
                self.userIsLoggedIn = true
                self.errorMessage = nil
            }
        }
    }

    func signUp() {
        guard !email.isEmpty, !password.isEmpty, !username.isEmpty else {
            self.errorMessage = "Please fill in all fields."
            return
        }
        
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }
            
            guard let user = result?.user else { return }

            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = self.username
            changeRequest.commitChanges { error in
                if let error = error {
                    print("DEBUG: Error setting display name: \(error.localizedDescription)")
                }
            }
            
            let db = Firestore.firestore()
            db.collection("users").document(user.uid).setData([
                "username": self.username.lowercased(),
                "email": self.email,
                "uid": user.uid
            ]) { error in
                if let error = error {
                    self.errorMessage = "Error saving user data: \(error.localizedDescription)"
                } else {
                    self.userIsLoggedIn = true
                    self.errorMessage = nil
                }
            }
        }
    }
    
    func forgotPassword() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            self.errorMessage = "Please enter your email to reset your password."
            return
        }
        
        Auth.auth().sendPasswordReset(withEmail: trimmedEmail) { error in
            if let error = error {
                self.errorMessage = error.localizedDescription
            } else {
                self.errorMessage = nil
                self.showingPasswordResetAlert = true
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}

