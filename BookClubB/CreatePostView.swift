//
//  CreatePostView.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//  Modified 6/11/25 to use Firestore “username” instead of displayName
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct CreatePostView: View {
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var postBody = ""
    @State private var errorMessage: String?

    @StateObject private var viewModel = PostViewModel()

    var body: some View {
        NavigationView {
            Form {
                // ––– Title Section –––
                Section(header: Text("Title")) {
                    TextField("Post title", text: $title)
                }

                // ––– Body Section –––
                Section(header: Text("Body")) {
                    TextEditor(text: $postBody)
                        .frame(height: 150)
                }

                // If there’s an error (e.g., failed to fetch username), show it here
                if let errorMessage = errorMessage {
                    Section {
                        Text("❌ \(errorMessage)")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("New Post")
            .toolbar {
                // Save button: Disabled if title/body empty or no signed-in user
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

                // Cancel button simply dismisses
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    /// 1) Ensure we have a signed-in user.
    /// 2) Look up their Firestore document (“/users/{uid}”) to get “username”.
    /// 3) Call viewModel.addPost(author: username, …).
    private func savePost() {
        guard let currentUser = Auth.auth().currentUser else {
            // Should never be triggered, since Save is disabled when user == nil
            errorMessage = "You must be signed in to create a post."
            return
        }

        let currentUID = currentUser.uid
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(currentUID)

        // Fetch the “username” field from Firestore
        userRef.getDocument { snapshot, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to fetch username: \(error.localizedDescription)"
                }
                return
            }

            // Extract “username” or default to “Anonymous”
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

            // Prepare trimmed title/body
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedBody = postBody.trimmingCharacters(in: .whitespacesAndNewlines)

            // Finally, create the Post document in Firestore.
            viewModel.addPost(author: fetchedUsername, title: trimmedTitle, body: trimmedBody)

            // Dismiss after scheduling the write
            DispatchQueue.main.async {
                dismiss()
            }
        }
    }
}

// SwiftUI Preview
#Preview {
    CreatePostView()
}
