//
//  ThreadDetailView.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 6/1/25.
//  Updated 6/1/25 to remove the `username` argument from ProfileView (ProfileView() now takes no parameters).
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ThreadDetailView: View {
    let groupID: String
    let thread: GroupThread

    // Local, mutable “like” state derived from the passed‐in GroupThread
    @State private var isLikedByCurrentUser: Bool
    @State private var likesCount: Int

    @StateObject private var viewModel = ThreadDetailViewModel()
    @State private var showingNewReplySheet: Bool = false
    @State private var isMember: Bool = false

    @Environment(\.dismiss) private var dismissView

    // Initialize @State variables from the incoming `thread`
    init(groupID: String, thread: GroupThread) {
        self.groupID = groupID
        self.thread = thread
        _isLikedByCurrentUser = State(initialValue: false)
        _likesCount            = State(initialValue: thread.likeCount)
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Parent thread’s header info ──
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    // Placeholder circle for an avatar (GroupThread has no avatarUrl)
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 50, height: 50)

                    VStack(alignment: .leading, spacing: 4) {
                        // Now just opens ProfileView() without arguments
                        NavigationLink(destination: ProfileView()) {
                            Text(thread.authorID)
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        Text(thread.timestamp, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                Text(thread.content)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                // ── Tappable “like” + “reply” counts ──
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

            // ── Replies list ──
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

            // ── “Add Reply” button (only if the user is a member) ──
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
                        .padding(.bottom, 20)
                }
                .sheet(isPresented: $showingNewReplySheet) {
                    NewReplyView(
                        groupID: groupID,
                        threadID: thread.id
                    )
                }
            }
        }
        .navigationTitle("Thread")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // 1) Start listening for replies below this thread
            viewModel.bind(toGroupID: groupID, threadID: thread.id)

            // 2) Determine membership so we know whether to show “Add Reply”
            if let currentUser = Auth.auth().currentUser {
                let db = Firestore.firestore()
                db.collection("groups")
                  .document(groupID)
                  .getDocument { snapshot, _ in
                    if let data = snapshot?.data(),
                       let members = data["memberIDs"] as? [String] {
                        self.isMember = members.contains(currentUser.uid)
                    }
                  }
            }
        }
        .onDisappear {
            viewModel.detachListeners()
        }
    }

    // ───────────────────────────────────────────────────────────────────────────
    /// Toggle like/unlike for the current user on this thread.
    private func toggleLike() {
        guard let currentUID = Auth.auth().currentUser?.uid else {
            return
        }
        let db = Firestore.firestore()
        let threadRef = db
            .collection("groups")
            .document(groupID)
            .collection("threads")
            .document(thread.id)
        let likeDocRef = threadRef
            .collection("likes")
            .document(currentUID)

        likeDocRef.getDocument { snapshot, error in
            if let snapshot = snapshot, snapshot.exists {
                // Already liked → remove like
                let batch = db.batch()
                batch.deleteDocument(likeDocRef)
                batch.updateData([
                    "likeCount": FieldValue.increment(Int64(-1))
                ], forDocument: threadRef)

                batch.commit { batchError in
                    if let batchError = batchError {
                        print("Error unliking thread: \(batchError.localizedDescription)")
                    } else {
                        DispatchQueue.main.async {
                            isLikedByCurrentUser = false
                            likesCount = max(0, likesCount - 1)
                        }
                    }
                }
            } else {
                // Not yet liked → add like
                let batch = db.batch()
                batch.setData([ "createdAt": Timestamp(date: Date()) ], forDocument: likeDocRef)
                batch.updateData([
                    "likeCount": FieldValue.increment(Int64(1))
                ], forDocument: threadRef)

                batch.commit { batchError in
                    if let batchError = batchError {
                        print("Error liking thread: \(batchError.localizedDescription)")
                    } else {
                        DispatchQueue.main.async {
                            isLikedByCurrentUser = true
                            likesCount += 1
                        }
                    }
                }
            }
        }
    }
}

// ───────────────────────────────────────────────────────────────────────────────
/// A single “reply” row.
struct ReplyRowView: View {
    let reply: Reply

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: reply.avatarUrl)) { phase in
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
                    // Now just opens ProfileView() without arguments
                    NavigationLink(destination: ProfileView()) {
                        Text(reply.username)
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.blue)
                    }
                    Text(reply.createdAt, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
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
