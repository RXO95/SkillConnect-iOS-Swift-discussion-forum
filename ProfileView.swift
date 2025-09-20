import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import PhotosUI
import FirebaseStorage
import Combine

class ProfileViewModel: ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var userPosts: [DiscussionPost] = []
    @Published var isLoading = true
    
    private let db = Firestore.firestore()
    private var userListener: ListenerRegistration?
    private var postsListener: ListenerRegistration?

    init() {
        fetchUserProfile()
    }
    
    deinit {
        userListener?.remove()
        postsListener?.remove()
    }
    
    func fetchUserProfile() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        self.isLoading = true
        
        userListener = db.collection("users").document(userId).addSnapshotListener { documentSnapshot, error in
            guard let document = documentSnapshot else {
                self.isLoading = false
                return
            }
            
            if !document.exists {
                if let user = Auth.auth().currentUser {
                    let newProfile = UserProfile(id: user.uid, username: user.displayName ?? "New User", bio: "Tap Edit to add a bio!", email: user.email ?? "")
                    self.db.collection("users").document(user.uid).setData([
                        "username": newProfile.username, "bio": newProfile.bio, "email": newProfile.email, "uid": user.uid, "skillPoints": 0
                    ])
                }
            } else {
                let data = document.data()
                self.userProfile = UserProfile(
                    id: userId,
                    username: data?["username"] as? String ?? "N/A",
                    bio: data?["bio"] as? String ?? "No bio.",
                    email: data?["email"] as? String ?? "N/A",
                    profileImageUrl: data?["profileImageUrl"] as? String,
                    skillPoints: data?["skillPoints"] as? Int ?? 0
                )
                self.fetchUserPosts(userId: userId)
            }
            self.isLoading = false
        }
    }
    
    func fetchUserPosts(userId: String) {
        postsListener = db.collection("discussions")
            .whereField("authorId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                self.userPosts = documents.compactMap { doc -> DiscussionPost? in
                    let data = doc.data()
                    return DiscussionPost(
                        id: doc.documentID,
                        title: data["title"] as? String ?? "",
                        body: data["body"] as? String ?? "",
                        authorId: data["authorId"] as? String ?? "",
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        commentCount: data["commentCount"] as? Int ?? 0
                    )
                }
            }
    }
}


struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var isEditing = false
    @State private var showingSettings = false

    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView()
                } else if let profile = viewModel.userProfile {
                    List {
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
                        }
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                        .padding(.vertical)
                        
                        Section(header: Text("My Posts")) {
                            if viewModel.userPosts.isEmpty {
                                Text("You haven't posted anything yet.")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(viewModel.userPosts) { post in
                                    NavigationLink(destination: PostDetailView(post: post)) {
                                        VStack(alignment: .leading) {
                                            Text(post.title).font(.headline)
                                            Text(post.createdAt, style: .date).font(.caption).foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .navigationTitle("Profile")
                    .navigationBarItems(
                        leading: Button(action: { isEditing = true }) {
                            Text("Edit Profile")
                        },
                        trailing: Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape.fill")
                        }
                    )
                    .sheet(isPresented: $isEditing) {
                        EditProfileView(userProfile: $viewModel.userProfile)
                    }
                    .sheet(isPresented: $showingSettings) {
                        SettingsView()
                    }
                } else {
                    Text("Could not load profile.")
                }
            }
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
        guard let userId = userProfile?.id else { return }
        isSaving = true

        if let photoData = selectedPhotoData {
            uploadPhoto(photoData) { url in
                self.updateUserDocument(userId: userId, photoUrl: url?.absoluteString)
            }
        } else {
            updateUserDocument(userId: userId, photoUrl: nil)
        }
    }
    
    func uploadPhoto(_ data: Data, completion: @escaping (URL?) -> Void) {
        let storageRef = Storage.storage().reference().child("profile_images/\(UUID().uuidString).jpg")
        storageRef.putData(data, metadata: nil) { _, error in
            storageRef.downloadURL { url, error in
                completion(url)
            }
        }
    }

    func updateUserDocument(userId: String, photoUrl: String?) {
        let db = Firestore.firestore()
        
        var dataToUpdate: [String: Any] = ["username": newUsername, "bio": newBio]
        if let photoUrl = photoUrl {
            dataToUpdate["profileImageUrl"] = photoUrl
        }
        
        db.collection("users").document(userId).updateData(dataToUpdate) { error in
            self.isSaving = false
            self.presentationMode.wrappedValue.dismiss()
        }
    }
}

