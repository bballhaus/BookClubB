//
//  PostViewModel.swift
//  BookClubB
//
//  Created by ChatGPT on 6/1/25.
//  Updated 6/11/25 to add an `addPost(author:title:body:)` method.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class PostViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var errorMessage: String?

    private var listenerRegistration: ListenerRegistration?

    init() {
        fetchPosts()
    }

    deinit {
        listenerRegistration?.remove()
    }

    /// Starts listening to the “posts” collection, ordered by timestamp descending.
    private func fetchPosts() {
        let db = Firestore.firestore()
        listenerRegistration = db
            .collection("posts")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to fetch posts: \(error.localizedDescription)"
                        self.posts = []
                    }
                    return
                }

                guard let docs = snapshot?.documents else {
                    DispatchQueue.main.async {
                        self.posts = []
                    }
                    return
                }

                let fetchedPosts = docs.compactMap { doc -> Post? in
                    return Post(id: doc.documentID, data: doc.data())
                }
                DispatchQueue.main.async {
                    self.posts = fetchedPosts
                }
            }
    }

    /// Creates a new post document in Firestore with the given author, title, and body.
    /// The `author` parameter should be the display name (e.g. “brooke”).
    func addPost(author: String, title: String, body: String) {
        // Ensure user is signed in so we can record UID if needed.
        guard let currentUID = Auth.auth().currentUser?.uid else {
            DispatchQueue.main.async {
                self.errorMessage = "You must be signed in to create a post."
            }
            return
        }

        let db = Firestore.firestore()
        let newPostRef = db.collection("posts").document() // auto‐generated ID

        let now = Date()
        let postData: [String: Any] = [
            "author":     author,
            "authorUID":  currentUID,                 // store the UID for navigation
            "title":      title.trimmingCharacters(in: .whitespacesAndNewlines),
            "body":       body.trimmingCharacters(in: .whitespacesAndNewlines),
            "timestamp":  Timestamp(date: now)
        ]

        newPostRef.setData(postData) { err in
            DispatchQueue.main.async {
                if let err = err {
                    self.errorMessage = "Failed to create post: \(err.localizedDescription)"
                }
                // On success, the Firestore listener will pick up the new post automatically.
            }
        }
    }
}
