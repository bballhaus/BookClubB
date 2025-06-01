//
//  NewReplyView.swift
//  BookClubB
//
//  Updated 6/1/25 to increment repliesCount on the parent thread.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct NewReplyView: View {
    @Environment(\.dismiss) private var dismiss

    let groupID: String
    let threadID: String

    /// Called when the reply was successfully posted (so the parent view can pop).
    let onReplyPosted: () -> Void

    // Fallback avatar (you can point this to a real placeholder image URL)
    private let defaultAvatar = "https://example.com/default-avatar.png"

    @State private var replyContent: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                TextEditor(text: $replyContent)
                    .border(Color.gray.opacity(0.4), width: 1)
                    .frame(minHeight: 150)
                    .padding(.horizontal)

                if let err = errorMessage {
                    Text(err)
                        .foregroundColor(.red)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                Button(action: submitReply) {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray)
                            .cornerRadius(8)
                    } else {
                        Text("Submit Reply")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
                .disabled(
                    replyContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || isSubmitting
                )
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("New Reply")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Cancel") {
                dismiss()
            })
        }
    }

    private func submitReply() {
        guard let currentUser = Auth.auth().currentUser else {
            errorMessage = "You must be signed in to reply."
            return
        }
        isSubmitting = true
        errorMessage = nil

        let username = currentUser.displayName ?? "Anonymous"
        let avatarUrl = defaultAvatar

        let db = Firestore.firestore()

        // 1) Create the new reply document
        let newReplyRef = db
            .collection("groups")
            .document(groupID)
            .collection("threads")
            .document(threadID)
            .collection("replies")
            .document() // Auto‐generated ID

        let now = Date()
        let replyData: [String: Any] = [
            "username":  username,
            "avatarUrl": avatarUrl,
            "content":   replyContent.trimmingCharacters(in: .whitespacesAndNewlines),
            "createdAt": Timestamp(date: now)
        ]

        newReplyRef.setData(replyData) { err in
            if let err = err {
                DispatchQueue.main.async {
                    self.isSubmitting = false
                    self.errorMessage = "Failed to reply: \(err.localizedDescription)"
                }
                return
            }

            // 2) Increment the parent thread’s repliesCount
            let threadRef = db
                .collection("groups")
                .document(groupID)
                .collection("threads")
                .document(threadID)

            threadRef.updateData([
                "repliesCount": FieldValue.increment(Int64(1))
            ]) { incErr in
                DispatchQueue.main.async {
                    self.isSubmitting = false

                    if let incErr = incErr {
                        // Even if increment fails, we already wrote the reply—so just show an error
                        self.errorMessage = "Reply saved, but failed to update count: \(incErr.localizedDescription)"
                    } else {
                        // 3) On completely successful flow, dismiss the sheet and notify parent
                        dismiss()
                        self.onReplyPosted()
                    }
                }
            }
        }
    }
}
