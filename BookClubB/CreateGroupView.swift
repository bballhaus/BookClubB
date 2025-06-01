//
//  CreateGroupView.swift
//  BookClubB
//
//  Created by Irene Lin on 5/31/25.
//  Updated: Pop back to Groups page on success.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss

    // ───────── Form Fields ─────────
    @State private var title: String = ""
    @State private var bookAuthor: String = ""
    @State private var imageUrl: String = ""
    @State private var moderationQuestion: String = ""
    @State private var correctAnswer: String = ""

    // ───────── State Flags ─────────
    @State private var isCreatingGroup: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showErrorAlert: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Create a New Book Group")
                .font(.largeTitle)
                .bold()
                .padding(.top)

            // ─── Book Title ───
            Group {
                Text("Book Title")
                    .font(.headline)
                TextField("Enter book title", text: $title)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            // ─── Book Author ───
            Group {
                Text("Book Author")
                    .font(.headline)
                TextField("Enter book author", text: $bookAuthor)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            // ─── Image URL ───
            Group {
                Text("Book Image URL")
                    .font(.headline)
                TextField("https://example.com/cover.jpg", text: $imageUrl)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .keyboardType(.URL)
            }

            // ─── Moderation Question ───
            Group {
                Text("Provide a question to make sure new members have read the book.")
                    .font(.headline)
                TextField("E.g. Who is the protagonist?", text: $moderationQuestion)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            // ─── Correct Answer ───
            Group {
                Text("Correct Answer")
                    .font(.headline)
                TextField("Enter the correct answer here", text: $correctAnswer)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            // Show any error message
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.subheadline)
            }

            Spacer()

            // ─── Create Group Button ───
            Button(action: createNewGroup) {
                HStack {
                    Spacer()
                    if isCreatingGroup {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Create Group")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding()
                .background(isCreatingGroup ? Color.gray : Color.blue)
                .cornerRadius(8)
            }
            .disabled(
                isCreatingGroup ||
                title.isEmpty ||
                bookAuthor.isEmpty ||
                imageUrl.isEmpty ||
                moderationQuestion.isEmpty ||
                correctAnswer.isEmpty
            )
        }
        .padding()
        .navigationBarTitle("New Group", displayMode: .inline)
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage ?? "Unknown error"),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: – Private Methods

    private func createNewGroup() {
        guard let currentUser = Auth.auth().currentUser else {
            errorMessage = "You must be signed in to create a group."
            showErrorAlert = true
            return
        }

        isCreatingGroup = true
        errorMessage = nil

        let newID = UUID().uuidString
        let now = Date()

        let newGroup = BookGroup(
            id: newID,
            title: title,
            bookAuthor: bookAuthor,
            ownerID: currentUser.uid,
            imageUrl: imageUrl,
            moderationQuestion: moderationQuestion,
            correctAnswer: correctAnswer,
            memberIDs: [currentUser.uid],
            createdAt: now,
            updatedAt: now
        )

        let db = Firestore.firestore()
        db.collection("groups").document(newID).setData(newGroup.asDictionary()) { err in
            DispatchQueue.main.async {
                self.isCreatingGroup = false
                if let err = err {
                    self.errorMessage = "Error creating group: \(err.localizedDescription)"
                    self.showErrorAlert = true
                } else {
                    // On success, dismiss back to the Groups page
                    dismiss()
                }
            }
        }
    }
}

// MARK: – Preview

struct CreateGroupView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CreateGroupView()
        }
    }
}
