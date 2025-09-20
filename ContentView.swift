import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import Combine
import PhotosUI
import FirebaseStorage

struct UserProfile: Identifiable {
    var id: String
    var username: String
    var bio: String
    var email: String
    var profileImageUrl: String?
    var skillPoints: Int = 0
}

struct DiscussionPost: Identifiable {
    var id: String
    var title: String
    var body: String
    var authorId: String
    var createdAt: Date
    var author: UserProfile?
    var commentCount: Int = 0
}

struct Comment: Identifiable, Equatable {
    var id: String
    var text: String
    var authorId: String
    var createdAt: Date
    var skillPoints: Int
    var author: UserProfile?

    static func == (lhs: Comment, rhs: Comment) -> Bool {
        lhs.id == rhs.id
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            ForumView()
                .tabItem {
                    Label("Forum", systemImage: "bubble.left.and.bubble.right.fill")
                }

            AddPostView()
                .tabItem {
                    Label("Post", systemImage: "plus.square.fill")
                }
            
            NotificationsView()
                .tabItem {
                    Label("Notifications", systemImage: "bell.fill")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .tint(.purple)
    }
}




struct ForumRowView: View {
    let post: DiscussionPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AsyncImage(url: URL(string: post.author?.profileImageUrl ?? "")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill").foregroundColor(.gray)
                }
                .frame(width: 25, height: 25)
                .clipShape(Circle())
                
                Text(post.author?.username ?? "Anonymous")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            
            Text(post.title)
                .font(.headline)
                .fontWeight(.bold)
                
            Text(post.body)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Image(systemName: "bubble.left")
                Text("\(post.commentCount)")
            }
            .font(.caption)
            .foregroundColor(.gray)
            .padding(.top, 4)
        }
        .padding(.vertical, 8)
    }
}

class PostDetailViewModel: ObservableObject {
    @Published var comments = [Comment]()
    private let db = Firestore.firestore()

    func fetchComments(for postID: String) {
        db.collection("discussions").document(postID).collection("comments").order(by: "createdAt").addSnapshotListener { querySnapshot, error in
            guard let documents = querySnapshot?.documents else { return }
            
            self.comments = []
            for document in documents {
                let data = document.data()
                let id = document.documentID
                let text = data["text"] as? String ?? ""
                let authorId = data["authorId"] as? String ?? ""
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                let skillPoints = data["skillPoints"] as? Int ?? 0
                
                var comment = Comment(id: id, text: text, authorId: authorId, createdAt: createdAt, skillPoints: skillPoints)
                
                self.fetchAuthor(for: authorId) { userProfile in
                    comment.author = userProfile
                    if let index = self.comments.firstIndex(where: { $0.id == comment.id }) {
                        self.comments[index] = comment
                    } else {
                        self.comments.append(comment)
                    }
                }
            }
        }
    }
    
    @MainActor
    func addComment(text: String, postID: String, authorID: String) async throws {
        let postRef = db.collection("discussions").document(postID)
        
        try await db.runTransaction { (transaction, errorPointer) -> Any? in
            do {
                let postDocument = try transaction.getDocument(postRef)
                let currentCount = postDocument.data()?["commentCount"] as? Int ?? 0
                transaction.updateData(["commentCount": currentCount + 1], forDocument: postRef)
                
                let newCommentRef = postRef.collection("comments").document()
                transaction.setData([
                    "text": text,
                    "authorId": authorID,
                    "createdAt": Timestamp(date: Date()),
                    "skillPoints": 0
                ], forDocument: newCommentRef)
                
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            return nil
        }
    }
    
    @MainActor
    func awardSkillPoint(to comment: Comment, in postID: String) async throws {
        let commentRef = db.collection("discussions").document(postID).collection("comments").document(comment.id)
        let userRef = db.collection("users").document(comment.authorId)
        
        try await db.runTransaction { (transaction, errorPointer) -> Any? in
            do {
                _ = try transaction.getDocument(commentRef)
                _ = try transaction.getDocument(userRef)
                
                transaction.updateData(["skillPoints": FieldValue.increment(Int64(1))], forDocument: commentRef)
                transaction.updateData(["skillPoints": FieldValue.increment(Int64(1))], forDocument: userRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            return nil
        }
    }
    
    private func fetchAuthor(for userId: String, completion: @escaping (UserProfile?) -> Void) {
        db.collection("users").document(userId).getDocument { document, _ in
            guard let document = document, document.exists, let data = document.data() else {
                completion(nil)
                return
            }
            completion(UserProfile(
                id: userId,
                username: data["username"] as? String ?? "Unknown",
                bio: data["bio"] as? String ?? "",
                email: data["email"] as? String ?? "",
                profileImageUrl: data["profileImageUrl"] as? String,
                skillPoints: data["skillPoints"] as? Int ?? 0
            ))
        }
    }
}

struct PostDetailView: View {
    let post: DiscussionPost
    @StateObject private var viewModel = PostDetailViewModel()
    @State private var newCommentText: String = ""
    
    var body: some View {
        VStack(alignment: .leading) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(post.title).font(.largeTitle).fontWeight(.bold)
                    Text(post.body).font(.body)
                    Divider()
                    Text("Comments").font(.headline)
                }
                .padding()
                
                ForEach(viewModel.comments) { comment in
                    CommentRowView(comment: comment) {
                        Task {
                            do {
                                try await viewModel.awardSkillPoint(to: comment, in: post.id)
                            } catch {
                                print("Error awarding skill point: \(error)")
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            HStack {
                TextField("Add a comment...", text: $newCommentText)
                    .textFieldStyle(.roundedBorder)
                Button(action: addComment) {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(newCommentText.isEmpty)
            }
            .padding()
        }
        .navigationTitle("Discussion")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.fetchComments(for: post.id)
        }
    }
    
    private func addComment() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        Task {
            do {
                try await viewModel.addComment(text: newCommentText, postID: post.id, authorID: userId)
                newCommentText = ""
            } catch {
                print("Error adding comment: \(error)")
            }
        }
    }
}

struct CommentRowView: View {
    let comment: Comment
    var onAwardPoint: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AsyncImage(url: URL(string: comment.author?.profileImageUrl ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.circle.fill").foregroundColor(.gray)
            }
            .frame(width: 35, height: 35)
            .clipShape(Circle())
            
            VStack(alignment: .leading) {
                Text(comment.author?.username ?? "Anonymous").fontWeight(.bold)
                Text(comment.text)
            }
            
            Spacer()
            
            Button(action: onAwardPoint) {
                VStack {
                    Image(systemName: "brain.head.profile")
                        .font(.title3)
                    Text("\(comment.skillPoints)")
                        .font(.caption)
                }
                .foregroundColor(.purple)
            }
        }
        .padding(.vertical, 8)
    }
}

struct AddPostView: View {
    @State private var title = ""
    @State private var bodyText = ""
    @State private var errorMessage: String?
    @State private var postCreated = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("New Discussion")) {
                    TextField("Title", text: $title)
                    TextEditor(text: $bodyText)
                        .frame(height: 200)
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage).foregroundColor(.red)
                }
                
                Button(action: createPost) {
                    Text("Post Discussion").foregroundColor(.blue)
                }
                .disabled(title.isEmpty || bodyText.isEmpty)
            }
            .navigationTitle("Start a Discussion")
            .alert("Success", isPresented: $postCreated) {
                Button("OK", role: .cancel) {
                    title = ""
                    bodyText = ""
                }
            } message: { Text("Your discussion has been posted.") }
        }
    }
    
    func createPost() {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "You must be logged in to post."
            return
        }
        
        let db = Firestore.firestore()
        db.collection("discussions").addDocument(data: [
            "title": title,
            "body": bodyText,
            "authorId": userId,
            "createdAt": Timestamp(date: Date()),
            "commentCount": 0
        ]) { error in
            if let error = error {
                errorMessage = "Error: \(error.localizedDescription)"
            } else {
                errorMessage = nil
                postCreated = true
            }
        }
    }
}

struct NotificationsView: View {
    var body: some View {
        NavigationView {
            Text("You have no new notifications.")
                .navigationTitle("Notifications")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

