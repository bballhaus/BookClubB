////
////  PostViewModel.swift
////  BookClubB
////
////  Created by Brooke Ballhaus on 5/31/25.
////
//
//import Foundation
//import FirebaseFirestore
//import Combine
//
//class PostViewModel: ObservableObject {
//    @Published var posts: [Post] = []
//    private var db = Firestore.firestore()
//    private var listenerRegistration: ListenerRegistration?
//
//    init() {
//        fetchPosts()
//    }
//
//    func fetchPosts() {
//        listenerRegistration = db.collection("posts")
//            .order(by: "timestamp", descending: true)
//            .addSnapshotListener { [weak self] snapshot, error in
//                if let error = error {
//                    print("Error fetching posts: \(error.localizedDescription)")
//                    return
//                }
//                guard let documents = snapshot?.documents else {
//                    print("No posts found")
//                    return
//                }
//                self?.posts = documents.compactMap { doc in
//                    try? doc.data(as: Post.self)
//                }
//            }
//    }
//
//    deinit {
//        listenerRegistration?.remove()
//    }
//
//    func addPost(author: String, title: String, body: String) {
//        let newPost = Post(id: nil, author: author, title: title, body: body, timestamp: Date())
//        do {
//            _ = try db.collection("posts").addDocument(from: newPost)
//        } catch {
//            print("Error adding post: \(error)")
//        }
//    }
//}
