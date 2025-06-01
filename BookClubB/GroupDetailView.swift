//
//  GroupDetailView.swift
//  BookClubB
//
//  Created by Irene Lin on 5/31/25.
//  Updated 6/3/25 to navigate to ThreadDetailView when tapping the reply button.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct GroupDetailView: View {
    let groupID: String

    /// ViewModel listening to “group” document + its “threads” subcollection
    @StateObject private var viewModel = GroupDetailViewModel()

    /// Controls presentation of the “New Thread” sheet
    @State private var showingNewThreadSheet: Bool = false

    @State private var answer: String = ""
    @State private var showJoinError: Bool = false
    @State private var joinErrorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ── If the group data has loaded, display it ──
            if let group = viewModel.group {
                // ── Header: title, author, member count ──
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

                // ── If the current user is not yet a member, show moderation question ──
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

                // ── If the user is a member, show “Posts” (threads) ──
                if viewModel.isMember {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Posts")
                            .font(.headline)
                            .padding(.horizontal)

                        // ── List of existing threads ──
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.threads) { thread in
                                    ThreadView(
                                        groupID: groupID,
                                        thread: thread,
                                        viewModel: viewModel
                                    )
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.vertical)
                        }

                        // ── “Add Post” button ──
                        Button(action: {
                            showingNewThreadSheet = true
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
                        .sheet(isPresented: $showingNewThreadSheet) {
                            NewThreadView(groupID: groupID)
                        }
                    }
                }
                // ── If the user has already answered but is not yet approved ──
                else if viewModel.hasAnswered {
                    Text("Your answer was submitted. Waiting for approval.")
                        .italic()
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top)
                }

                Spacer()
            }
            // ── If group data is not yet available, show a loading indicator ──
            else {
                VStack {
                    ProgressView()
                        .padding(.top, 40)
                    Text("Loading group…")
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

    // ─────────────────────────────────────────────────────────────────
    /// Called when the user submits a moderation answer to join
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
                    viewModel.bind(to: groupID)
                }
            }
        }
    }
}

/// Renders a single post/thread row, including tappable like & reply buttons
struct ThreadView: View {
    let groupID: String
    let thread: ThreadModel

    @ObservedObject var viewModel: GroupDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ── Avatar, username, timestamp ──
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

            // ── Thread content text ──
            Text(thread.content)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            // ── Only “like” and “reply” icons ──
            HStack(spacing: 24) {
                Button(action: {
                    viewModel.toggleLike(groupID: groupID, threadID: thread.id)
                }) {
                    if thread.isLikedByCurrentUser {
                        Image(systemName: "heart.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                    } else {
                        Image(systemName: "heart")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                }

                // Wrap reply icon in a NavigationLink to go to ThreadDetailView
                NavigationLink(
                    destination: ThreadDetailView(
                        groupID: groupID,
                        thread: thread
                    )
                ) {
                    Image(systemName: "bubble.right")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
            }
            .font(.title3)

            // ── Footer with “likes” first, then “replies” ──
            HStack(spacing: 8) {
                Text("\(thread.likesCount) likes")
                Text("·")
                Text("\(thread.repliesCount) replies")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            Divider()
        }
    }
}
