//
//  GroupDetailView.swift
//  BookClubB
//
//  Created by Irene Lin on 5/31/25.
//  Updated to remove duplicate Thread and fix property wrappers.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct GroupDetailView: View {
    let groupID: String

    /// Use @StateObject so SwiftUI knows this view owns the ViewModel
    @StateObject private var viewModel = GroupDetailViewModel()

    @State private var answer: String = ""
    @State private var showJoinError: Bool = false
    @State private var joinErrorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let group = viewModel.group {
                // ─── Header ───
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.title)
                        .font(.largeTitle)
                        .bold()

                    Text("By \(group.bookAuthor)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        // Show up to three placeholder circles for members
                        ForEach(Array(group.memberIDs.prefix(3)), id: \.self) { _ in
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

                // ─── Moderation question if not a member yet ───
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

                // ─── Threads section (only for members) ───
                if viewModel.isMember {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Posts")
                            .font(.headline)
                            .padding(.horizontal)

                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.threads) { thread in
                                    ThreadView(thread: thread)
                                        .padding(.horizontal)
                                }
                            }
                            .padding(.vertical)
                        }

                        // “Add Post” button at the bottom
                        Button(action: {
                            // TODO: present your “create new thread” UI here
                        }) {
                            Text("Add Post")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.black)
                                .cornerRadius(12)
                                .padding(.horizontal)
                                .padding(.bottom, 16)
                        }
                    }
                }
                else if viewModel.hasAnswered {
                    // They answered, now awaiting approval
                    Text("Your answer was submitted. Waiting for approval.")
                        .italic()
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top)
                }

                Spacer()
            } else {
                // Loading state
                VStack {
                    ProgressView()
                        .padding(.top, 40)
                    Text("Loading group…")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // Use an inline nav bar title (since the parent likely sets a large title)
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
                    // Once they become a member, re-bind so threads start updating
                    viewModel.bind(to: groupID)
                }
            }
        }
    }
}

/// Renders a single post/thread (uses the single `Thread` type from the ViewModel)
struct ThreadView: View {
    let thread: Thread  // <-- This is the same Thread from GroupDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ── Poster info (avatar + username + timestamp) ──
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: thread.avatarUrl)) { phase in
                    switch phase {
                    case .empty:
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 40, height: 40)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    case .failure:
                        Circle()
                            .fill(Color.red.opacity(0.1))
                            .overlay(
                                Image(systemName: "person.fill.exclamationmark")
                                    .foregroundColor(.red)
                            )
                            .frame(width: 40, height: 40)
                    @unknown default:
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 40, height: 40)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(thread.username)
                        .font(.subheadline)
                        .bold()

                    Text(thread.createdAt, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // ── The thread’s content text ──
            Text(thread.content)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            // ── Icons row (heart, comment, share, send) ──
            HStack(spacing: 24) {
                Image(systemName: "heart")
                Image(systemName: "bubble.right")
                Image(systemName: "arrow.2.squarepath")
                Image(systemName: "paperplane")
            }
            .font(.title3)
            .foregroundColor(.gray)

            // ── Footer with replies & likes count ──
            HStack(spacing: 8) {
                Text("\(thread.repliesCount) replies")
                Text("·")
                Text("\(thread.likesCount) likes")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            Divider()
        }
    }
}

