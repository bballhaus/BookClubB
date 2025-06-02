//
//  ThreadDetailView.swift
//  BookClubB
//
//  Updated 6/2/25: Avatars are now “first‐letter of username” circles.
//  Tapping author’s name uses username (not displayName).
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ThreadDetailView: View {
    let groupID: String
    let thread: GroupThread

    @State private var isLikedByCurrentUser: Bool
    @State private var likesCount: Int

    @StateObject private var viewModel = ThreadDetailViewModel()
    @State private var showingNewReplySheet = false
    @State private var isMember = false

    @Environment(\.dismiss) private var dismissView

    init(groupID: String, thread: GroupThread) {
        self.groupID = groupID
        self.thread = thread
        _isLikedByCurrentUser = State(initialValue: false)
        _likesCount = State(initialValue: thread.likeCount)
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Parent thread header ───────────────────────────────────────
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    // Avatar circle with first letter of thread.authorID
                    let firstLetter = String(thread.authorID.prefix(1)).uppercased()
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(firstLetter)
                                .font(.headline)
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        // Tapping “thread.authorID” → ProfileView(username: thread.authorID)
                        NavigationLink(destination: ProfileView(username: thread.authorID)) {
                            Text(thread.authorID)
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Text(thread.timestamp, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                Text(thread.content)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                // Like / reply counts
                HStack(spacing: 16) {
                    Button(action: toggleLike) {
                        if isLikedByCurrentUser {
                            Image(systemName: "heart.fill")
                                .font(.title3)
                                .foregroundColor(.red)
                        } else {
                            Image(systemName: "heart")
                                .font(.title3)
                                .foregroundColor(.gray)
                        }
                    }
                    .disabled(!isMember)

                    Text("\(likesCount)")
                        .font(.subheadline)

                    Image(systemName: "bubble.right")
                        .font(.title3)
                        .foregroundColor(.gray)

                    Text("\(thread.replyCount)")
                        .font(.subheadline)

                    Spacer()
                }
                .foregroundColor(.gray)

                Divider()
            }
            .padding()

            // ── Replies List ───────────────────────────────────────────────
            if let error = viewModel.errorMessage {
                Text("❌ \(error)")
                    .foregroundColor(.red)
                    .padding()
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.replies) { reply in
                            ReplyRowView(reply: reply)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }

            Divider()

            // ── “Add Reply” button for members ─────────────────────────────
            if isMember {
                Button(action: {
                    showingNewReplySheet = true
                }) {
                    Text("Add Reply")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                }
                .sheet(isPresented: $showingNewReplySheet) {
                    NewReplyView(groupID: groupID, threadID: thread.id)
                }
            }
        }
        .onAppear {
            viewModel.bind(toGroupID: groupID, threadID: thread.id)

            if let currentUser = Auth.auth().currentUser {
                Firestore.firestore()
                    .collection("groups")
                    .document(groupID)
                    .getDocument { snapshot, _ in
                        if let members = snapshot?
                            .data()?["memberIDs"] as? [String] {
                            self.isMember = members.contains(currentUser.uid)
                        }
                    }
            }
        }
        .onDisappear {
            viewModel.detachListeners()
        }
        .navigationTitle("Thread")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggleLike() {
        guard let currentUID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let threadRef = db
            .collection("groups")
            .document(groupID)
            .collection("threads")
            .document(thread.id)
        let likeDocRef = threadRef.collection("likes").document(currentUID)

        likeDocRef.getDocument { snapshot, _ in
            if let snapshot = snapshot, snapshot.exists {
                // Remove like
                let batch = db.batch()
                batch.deleteDocument(likeDocRef)
                batch.updateData(["likeCount": FieldValue.increment(Int64(-1))],
                                 forDocument: threadRef)
                batch.commit { _ in
                    DispatchQueue.main.async {
                        isLikedByCurrentUser = false
                        likesCount = max(0, likesCount - 1)
                    }
                }
            } else {
                // Add like
                let batch = db.batch()
                batch.setData(["createdAt": Timestamp(date: Date())],
                              forDocument: likeDocRef)
                batch.updateData(["likeCount": FieldValue.increment(Int64(1))],
                                 forDocument: threadRef)
                batch.commit { _ in
                    DispatchQueue.main.async {
                        isLikedByCurrentUser = true
                        likesCount += 1
                    }
                }
            }
        }
    }
}


/// A single “reply” row. Avatar is first letter of reply.username,
/// tapping the name uses ProfileView(username: reply.username).
struct ReplyRowView: View {
    let reply: Reply

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Avatar circle with first letter of reply.username
                let letter = String(reply.username.prefix(1)).uppercased()
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(letter)
                            .font(.subheadline).bold()
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    // Tapping “reply.username” → ProfileView(username: reply.username)
                    NavigationLink(destination: ProfileView(username: reply.username)) {
                        Text(reply.username)
                            .font(.subheadline).bold()
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Text(reply.createdAt, style: .time)
                        .font(.caption).foregroundColor(.secondary)
                }

                Spacer()
            }

            Text(reply.content)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
        }
    }
}
