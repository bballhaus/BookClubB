//
//  CreatePostView.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var postBody = ""
    @State private var errorMessage: String?

    @StateObject private var viewModel = PostViewModel()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Title")) {
                    TextField("Post title", text: $title)
                }

                Section(header: Text("Body")) {
                    TextEditor(text: $postBody)
                        .frame(height: 150)
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text("❌ \(errorMessage)")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("New Post")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePost()
                    }
                    .disabled(
                        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        postBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        Auth.auth().currentUser == nil
                    )
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func savePost() {
        guard let currentUser = Auth.auth().currentUser else {
            errorMessage = "You must be signed in."
            return
        }

        let currentUID = currentUser.uid
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(currentUID)

        // Fetch the user’s “username” field (immutable handle), not the displayName
        userRef.getDocument { snapshot, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to fetch username: \(error.localizedDescription)"
                }
                return
            }

            let fetchedUsername: String
            if
                let data = snapshot?.data(),
                let username = data["username"] as? String,
                !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                fetchedUsername = username
            } else {
                fetchedUsername = "Anonymous"
            }

            // Write the Post doc under “posts”
            let postRef = db.collection("posts").document()  

            let now = Date()
            let postData: [String: Any] = [
                "author":    fetchedUsername,       // this is the username
                "authorUID": currentUID,
                "title":     title.trimmingCharacters(in: .whitespacesAndNewlines),
                "body":      postBody.trimmingCharacters(in: .whitespacesAndNewlines),
                "timestamp": Timestamp(date: now)
            ]

            postRef.setData(postData) { err in
                DispatchQueue.main.async {
                    if let err = err {
                        self.errorMessage = "Failed to post: \(err.localizedDescription)"
                        return
                    }
                    dismiss()
                }
            }
        }
    }
}
