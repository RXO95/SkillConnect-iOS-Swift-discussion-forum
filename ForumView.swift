import SwiftUI
import Firebase
import FirebaseFirestore
import Combine

class ForumViewModel: ObservableObject {
    @Published var posts: [DiscussionPost] = []
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    init() {
        fetchPosts()
    }
    
    deinit {
        listener?.remove()
    }

    func fetchPosts() {
        listener = db.collection("discussions")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }
                
                var newPosts: [DiscussionPost] = []
                let group = DispatchGroup()
                
                for doc in documents {
                    group.enter()
                    let data = doc.data()
                    let authorId = data["authorId"] as? String ?? ""
                    
                    var post = DiscussionPost(
                        id: doc.documentID,
                        title: data["title"] as? String ?? "",
                        body: data["body"] as? String ?? "",
                        authorId: authorId,
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        commentCount: data["commentCount"] as? Int ?? 0
                    )
                    
                    self.fetchAuthor(for: authorId) { authorProfile in
                        post.author = authorProfile
                        newPosts.append(post)
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    self.posts = newPosts.sorted(by: { $0.createdAt > $1.createdAt })
                }
            }
    }

    private func fetchAuthor(for userId: String, completion: @escaping (UserProfile?) -> Void) {
        db.collection("users").document(userId).getDocument { snapshot, _ in
            guard let data = snapshot?.data() else { completion(nil); return }
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


struct ForumView: View {
    @StateObject private var viewModel = ForumViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.posts) { post in
                        NavigationLink(destination: PostDetailView(post: post)) {
                            ForumPostCardView(post: post)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Discussions")
        }
    }
}

struct ForumPostCardView: View {
    let post: DiscussionPost

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                AsyncImage(url: URL(string: post.author?.profileImageUrl ?? "")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill").foregroundColor(.gray.opacity(0.6))
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.author?.username ?? "Anonymous")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(timeAgo(from: post.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text(post.title)
                .font(.title3)
                .fontWeight(.bold)

            Text(post.body)
                .font(.body)
                .lineLimit(3)
                .foregroundColor(.secondary)

            HStack {
                Spacer()
                Label("\(post.commentCount)", systemImage: "bubble.left.fill")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
        .padding(.bottom, 12)
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

