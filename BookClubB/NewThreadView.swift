//
//  NewThreadView.swift
//  BookClubB
//
//  Created by YourName on 6/1/25.
//  Updated 6/12/25 to include:
//    • an `isModerator` parameter
//    • a `Toggle("Tag as Mod")` that writes `"isModTagged": true/false`
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct NewThreadView: View {
    let groupID: String
    let isModerator: Bool      // ← NEW: whether current user is a mod in this group

    @Environment(\.dismiss) private var dismiss

    @State private var postContent: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    // ── NEW: Track whether the moderator wants their thread to be tagged ──
    @State private var isModTagged: Bool = false

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

                // ── If this user is a moderator, show the “Tag as Mod” toggle ──
                if isModerator {
                    Toggle(isOn: $isModTagged) {
                        Text("Tag as Mod")
                            .font(.subheadline)
                    }
                    .padding(.horizontal)
                }

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
        // ── INCLUDE “isModTagged” in the data ──
        let threadData: [String: Any] = [
            "username":     username,
            "authorUID":    currentUser.uid,
            "content":      postContent.trimmingCharacters(in: .whitespacesAndNewlines),
            "createdAt":    Timestamp(date: now),
            "likesCount":   0,
            "repliesCount": 0,
            "isModTagged":  isModTagged
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
        // Example preview in which isModerator = true:
        NewThreadView(groupID: "exampleGroupID", isModerator: true)
    }
}
