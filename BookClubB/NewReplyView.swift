//
//  NewReplyView.swift
//  BookClubB
//
//  Created by YourName on 6/1/25.
//  Updated 6/2/25 to simply call `dismiss()` when done,
//  so that we stay on ThreadDetailView after replying.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct NewReplyView: View {
    @Environment(\.dismiss) private var dismiss

    let groupID: String
    let threadID: String

    // Fallback avatar (any placeholder URL)
    private let defaultAvatar = "https://example.com/default-avatar.png"

    @State private var replyContent: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // TextEditor for typing the reply content
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
        // Ensure a user is signed in
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
            .document() // auto‐ID

        let now = Date()
        let replyData: [String: Any] = [
            "username":  username,
            "authorUID": currentUser.uid,                           // ← newly added
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
                        // We still dismiss the sheet even if increment fails
                        self.errorMessage = "Reply saved, but failed to update count: \(incErr.localizedDescription)"
                    }
                    // Dismiss the sheet so we remain on ThreadDetailView
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Preview
struct NewReplyView_Previews: PreviewProvider {
    static var previews: some View {
        NewReplyView(
            groupID: "SAMPLE_GROUP",
            threadID: "SAMPLE_THREAD"
        )
    }
}
