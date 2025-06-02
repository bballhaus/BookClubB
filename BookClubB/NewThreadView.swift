//
//  NewThreadView.swift
//  BookClubB
//
//  Created by YourName on 6/1/25.
//  Updated 6/10/25 to include “authorUID” when creating a new thread.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct NewThreadView: View {
    let groupID: String
    @Environment(\.dismiss) private var dismiss

    @State private var postContent: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                TextEditor(text: $postContent)
                    .frame(height: 150)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                    )
                    .padding()

                if let error = errorMessage {
                    Text("❌ \(error)")
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                Spacer()

                Button(action: submitThread) {
                    if isSubmitting {
                        ProgressView()
                            .padding(.vertical, 10)
                            .padding(.horizontal, 40)
                    } else {
                        Text("Post Thread")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 40)
                    }
                }
                .background(isSubmitting ? Color.gray.opacity(0.6) : Color.blue)
                .cornerRadius(8)
                .disabled(isSubmitting || postContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.bottom, 20)
            }
            .navigationTitle("New Thread")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func submitThread() {
        // Ensure a user is signed in
        guard let currentUser = Auth.auth().currentUser else {
            errorMessage = "You must be signed in to post."
            return
        }

        isSubmitting = true
        errorMessage = nil

        // Use the user’s displayName as the “username”
        let username = currentUser.displayName ?? "Anonymous"

        let db = Firestore.firestore()
        let newThreadRef = db
            .collection("groups")
            .document(groupID)
            .collection("threads")
            .document() // auto‐ID

        let now = Date()
        let threadData: [String: Any] = [
            "username":     username,
            "authorUID":    currentUser.uid,         // ← newly added
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
                    dismiss()
                }
            }
        }
    }
}

struct NewThreadView_Previews: PreviewProvider {
    static var previews: some View {
        NewThreadView(groupID: "exampleGroupID")
    }
}
