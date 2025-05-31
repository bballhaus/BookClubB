////
////  PostViewModel.swift
////  BookClubB
////
////  Created by Brooke Ballhaus on 5/31/25.
////
//
import Foundation
import FirebaseFirestore
import Combine

class PostViewModel: ObservableObject {
    @Published var posts: [Post] = []
    private var listenerRegistration: ListenerRegistration?

    private var db = Firestore.firestore()

    init() {
        fetchPosts()
    }

    func fetchPosts() {
        // Listen to the "posts" collection, ordered by timestamp descending
        listenerRegistration = db
            .collection("posts")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Error fetching posts: \(error.localizedDescription)")
                    return
                }
                guard let documents = snapshot?.documents else {
                    print("No posts found")
                    return
                }

                // Map each Firestore document to our Post model
                self?.posts = documents.compactMap { doc -> Post? in
                    let data = doc.data()  // [String: Any]
                    return Post(id: doc.documentID, data: data)
                }
            }
    }

    deinit {
        listenerRegistration?.remove()
    }

    func addPost(author: String, title: String, body: String) {
        // Prepare a dictionary for a new post
        let newData: [String: Any] = [
            "author": author,
            "title": title,
            "body": body,
            "timestamp": Timestamp(date: Date())
        ]
        db.collection("posts").addDocument(data: newData) { error in
            if let error = error {
                print("Error adding post: \(error.localizedDescription)")
            }
        }
    }
}
