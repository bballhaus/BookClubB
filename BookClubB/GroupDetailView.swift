//
//  GroupDetailView.swift
//  BookClubB
//
//  Created by Irene Lin on 5/31/25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct GroupDetailView: View {
    let groupID: String
    
    @StateObject private var viewModel = GroupDetailViewModel()
    @State private var answer: String = ""
    @State private var showJoinError: Bool = false
    @State private var joinErrorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let group = viewModel.group {
                // ───── Header ─────
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.title)
                        .font(.largeTitle)
                        .bold()

                    Text("by \(group.bookAuthor)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        // Show up to three member placeholders
                        ForEach(Array(group.memberIDs.prefix(3).enumerated()), id: \.offset) { _, _ in
                            Circle()
                                .fill(Color.gray.opacity(0.4))
                                .frame(width: 24, height: 24)
                        }
                        Text("\(group.memberIDs.count) members")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)

                // ───── Moderation Question (if not yet a member) ─────
                if !viewModel.isMember && !viewModel.hasAnswered {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Moderation Question:")
                            .font(.headline)
                        Text(group.moderationQuestion)
                            .font(.body)

                        TextField("Your answer", text: $answer)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        Button(action: submitAnswer) {
                            HStack {
                                Spacer()
                                Text("Submit Answer")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(8)
                        }
                        .disabled(answer.isEmpty)
                    }
                    .padding(.horizontal)
                }

                // ───── Threads (only if member) ─────
                if viewModel.isMember {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Threads")
                            .font(.headline)
                            .padding(.horizontal)

                        ScrollView {
                            ForEach(viewModel.threads.indices, id: \.self) { idx in
                                let thread = viewModel.threads[idx]
                                GroupThreadView(username: thread.username, content: thread.content)
                                    .padding(.horizontal)
                                    .padding(.bottom, 12)
                            }
                        }
                    }
                } else if viewModel.hasAnswered {
                    Text("Your answer was submitted. Waiting for approval.")
                        .italic()
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top)
                }

                Spacer()
            } else {
                // Loading / placeholder
                VStack {
                    ProgressView()
                        .padding(.top, 40)
                    Text("Loading group...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.bind(to: groupID)
        }
        .alert(isPresented: $showJoinError) {
            Alert(
                title: Text("Error"),
                message: Text(joinErrorMessage ?? "Unknown error"),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // When the user submits the moderation answer, add them to memberIDs
    private func submitAnswer() {
        guard let currentUser = Auth.auth().currentUser else {
            joinErrorMessage = "You must be signed in to join."
            showJoinError = true
            return
        }

        let db = Firestore.firestore()
        let groupRef = db.collection("groups").document(groupID)

        groupRef.updateData([
            "memberIDs": FieldValue.arrayUnion([currentUser.uid]),
            "updatedAt": Timestamp(date: Date())
        ]) { err in
            DispatchQueue.main.async {
                if let err = err {
                    joinErrorMessage = "Failed to join: \(err.localizedDescription)"
                    showJoinError = true
                } else {
                    // Refresh the group data so isMember becomes true
                    viewModel.bind(to: groupID)
                }
            }
        }
    }
}

// A single post/thread view within a group
struct GroupThreadView: View {
    var username: String
    var content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(username)
                .font(.subheadline)
                .bold()
            Text(content)
            HStack(spacing: 16) {
                Image(systemName: "heart")
                Image(systemName: "arrowshape.turn.up.right")
                Image(systemName: "paperplane")
            }
            .foregroundColor(.gray)
            .padding(.top, 4)
        }
    }
}

// MARK: – Preview

struct GroupDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            GroupDetailView(groupID: "dummyID")
        }
    }
}

