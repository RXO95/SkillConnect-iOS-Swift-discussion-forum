import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import PhotosUI
import FirebaseStorage

struct ProfileView: View {
    @State private var userProfile: UserProfile?
    @State private var isLoading = true
    @State private var isEditing = false

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView()
                } else if let profile = userProfile {
                    VStack(spacing: 20) {
                        AsyncImage(url: URL(string: profile.profileImageUrl ?? "")) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .resizable().scaledToFit().foregroundColor(.gray.opacity(0.5))
                        }
                        .frame(width: 120, height: 120).clipShape(Circle())

                        Text(profile.username).font(.largeTitle).fontWeight(.bold)
                        Text("Skill Points: \(profile.skillPoints)").font(.title3).foregroundColor(.purple).fontWeight(.semibold)
                        Text(profile.bio).font(.body).foregroundColor(.secondary).padding(.horizontal)
                        
                        Spacer()
                    }
                    .padding(.top, 40)
                    .navigationTitle("Profile")
                    .navigationBarItems(trailing: Button("Edit") { isEditing = true })
                    .sheet(isPresented: $isEditing, onDismiss: fetchUserProfile) {
                        EditProfileView(userProfile: $userProfile)
                    }
                } else {
                    Text("Could not load profile.")
                }
            }
            .onAppear(perform: fetchUserProfile)
        }
    }

    func fetchUserProfile() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        db.collection("users").document(userId).addSnapshotListener { documentSnapshot, error in
            guard let document = documentSnapshot, document.exists else {
                if let user = Auth.auth().currentUser {
                    let newProfile = UserProfile(id: user.uid, username: user.displayName ?? "New User", bio: "Tap Edit to add a bio!", email: user.email ?? "")
                    db.collection("users").document(user.uid).setData([
                        "username": newProfile.username, "bio": newProfile.bio, "email": newProfile.email, "uid": user.uid, "skillPoints": 0
                    ]) { _ in self.userProfile = newProfile }
                }
                self.isLoading = false
                return
            }
            
            let data = document.data()
            self.userProfile = UserProfile(
                id: userId,
                username: data?["username"] as? String ?? "N/A",
                bio: data?["bio"] as? String ?? "No bio.",
                email: data?["email"] as? String ?? "N/A",
                profileImageUrl: data?["profileImageUrl"] as? String,
                skillPoints: data?["skillPoints"] as? Int ?? 0
            )
            self.isLoading = false
        }
    }
}

struct EditProfileView: View {
    @Binding var userProfile: UserProfile?
    @State private var newUsername: String = ""
    @State private var newBio: String = ""
    
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var isSaving = false

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Public Profile")) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        VStack {
                            if let photoData = selectedPhotoData, let image = UIImage(data: photoData) {
                                Image(uiImage: image).resizable().scaledToFill()
                            } else {
                                AsyncImage(url: URL(string: userProfile?.profileImageUrl ?? "")) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Image(systemName: "person.circle.fill").resizable().scaledToFit().foregroundColor(.gray.opacity(0.5))
                                }
                            }
                        }
                        .frame(width: 100, height: 100).clipShape(Circle()).frame(maxWidth: .infinity)
                    }
                    
                    TextField("Username", text: $newUsername)
                    TextField("Bio", text: $newBio)
                }
                
                if isSaving { ProgressView() } else { Button("Save Changes") { saveProfile() } }
            }
            .navigationTitle("Edit Profile")
            .navigationBarItems(leading: Button("Cancel") { presentationMode.wrappedValue.dismiss() })
            .onAppear {
                if let profile = userProfile {
                    newUsername = profile.username
                    newBio = profile.bio
                }
            }
            .onChange(of: selectedPhotoItem) { newItem in
                Task {
                    do {
                        if let item = newItem,
                           let data = try await item.loadTransferable(type: Data.self) {
                            selectedPhotoData = data
                        }
                    } catch {
                        print("Failed to load photo data: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    func saveProfile() {
        guard userProfile?.id != nil else { return }
        isSaving = true

        if let photoData = selectedPhotoData {
            uploadPhoto(photoData) { url in
                self.updateUserDocument(photoUrl: url?.absoluteString)
            }
        } else {
            updateUserDocument(photoUrl: nil)
        }
    }
    
    func uploadPhoto(_ data: Data, completion: @escaping (URL?) -> Void) {
        let storageRef = Storage.storage().reference().child("profile_images/\(UUID().uuidString).jpg")
        storageRef.putData(data, metadata: nil) { _, _ in
            storageRef.downloadURL { url, _ in completion(url) }
        }
    }

    func updateUserDocument(photoUrl: String?) {
        guard let userId = userProfile?.id else { return }
        let db = Firestore.firestore()
        
        var dataToUpdate: [String: Any] = ["username": newUsername, "bio": newBio]
        if let photoUrl = photoUrl { dataToUpdate["profileImageUrl"] = photoUrl }
        
        db.collection("users").document(userId).updateData(dataToUpdate) { _ in
            isSaving = false
            presentationMode.wrappedValue.dismiss()
        }
    }
}
