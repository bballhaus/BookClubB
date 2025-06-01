//
//  NewThreadView.swift
//  BookClubB
//
//  Created by YourName on 6/1/25.
//  Updated 6/2/25 to accept an `onThreadPosted` closure.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct NewThreadView: View {
    @Environment(\.dismiss) private var dismiss

    let groupID: String

    /// Called when the thread was successfully posted
    let onThreadPosted: () -> Void

    // Fallback avatar URL (any placeholder you like)
    private let defaultAvatar = "https://example.com/default-avatar.png"

    @State private var postContent: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // TextEditor for typing the post content
                TextEditor(text: $postContent)
                    .border(Color.gray.opacity(0.4), width: 1)
                    .frame(minHeight: 150)
                    .padding(.horizontal)

                // Show any error below the editor
                if let err = errorMessage {
                    Text(err)
                        .foregroundColor(.red)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                // Submit button
                Button(action: submitThread) {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray)
                            .cornerRadius(8)
                    } else {
                        Text("Submit")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
                .disabled(
                    postContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || isSubmitting
                )
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Cancel") {
                dismiss()
            })
        }
    }

    private func submitThread() {
        // 1) Ensure a user is signed in
        guard let currentUser = Auth.auth().currentUser else {
            errorMessage = "You must be signed in to post."
            return
        }

        isSubmitting = true
        errorMessage = nil

        let username = currentUser.displayName ?? "Anonymous"
        let avatarUrl = defaultAvatar

        let db = Firestore.firestore()
        let newThreadRef = db
            .collection("groups")
            .document(groupID)
            .collection("threads")
            .document() // auto-generated ID

        let now = Date()
        let threadData: [String: Any] = [
            "username":     username,
            "avatarUrl":    avatarUrl,
            "content":      postContent.trimmingCharacters(in: .whitespacesAndNewlines),
            "createdAt":    Timestamp(date: now),
            "likesCount":   0,
            "repliesCount": 0
        ]

        newThreadRef.setData(threadData) { err in
            DispatchQueue.main.async {
                self.isSubmitting = false
                if let err = err {
                    self.errorMessage = "Failed to post: \(err.localizedDescription)"
                } else {
                    // 2) Successfully created thread → dismiss the sheet & inform parent
                    dismiss()
                    onThreadPosted()
                }
            }
        }
    }
}

// MARK: - Preview
struct NewThreadView_Previews: PreviewProvider {
    static var previews: some View {
        NewThreadView(
            groupID: "SAMPLE_GROUP_ID",
            onThreadPosted: { print("Thread posted!") }
        )
    }
}
