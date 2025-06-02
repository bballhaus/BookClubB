//
//  NewReplyView.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct NewReplyView: View {
    @Environment(\.dismiss) private var dismiss

    let groupID: String
    let threadID: String

    @State private var replyContent = ""
    @State private var isSubmitting = false
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
                        .padding(.horizontal)
                }

                Spacer()

                Button(action: submitReply) {
                    if isSubmitting {
                        ProgressView()
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gray)
                            .cornerRadius(8)
                            .padding(.horizontal)
                    } else {
                        Text("Submit Reply")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                }
                .disabled(
                    replyContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    isSubmitting
                )
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

        let db = Firestore.firestore()
        let userRef = db.collection("users").document(currentUser.uid)

        userRef.getDocument { snapshot, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.isSubmitting = false
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

            let newReplyRef = db
                .collection("groups")
                .document(groupID)
                .collection("threads")
                .document(threadID)
                .collection("replies")
                .document()

            let now = Date()
            let replyData: [String: Any] = [
                "username":  fetchedUsername,
                "authorUID": currentUser.uid,
                "content":   replyContent.trimmingCharacters(in: .whitespacesAndNewlines),
                "createdAt": Timestamp(date: now)
            ]

            newReplyRef.setData(replyData) { err in
                if let err = err {
                    DispatchQueue.main.async {
                        self.isSubmitting = false
                        self.errorMessage = "Failed to save reply: \(err.localizedDescription)"
                    }
                    return
                }

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
                            self.errorMessage = "Reply saved, but couldn’t update count: \(incErr.localizedDescription)"
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}
