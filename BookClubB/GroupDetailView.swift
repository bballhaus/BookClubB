//
//  GroupDetailView.swift
//  BookClubB
//
//  Created by Irene Lin on 5/31/25.
//  Modified 6/12/25 so that threads posted by moderators have a light-green background
//  and display a “MOD” tag next to their username.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct GroupDetailView: View {
    let groupID: String

    @StateObject private var viewModel = GroupDetailViewModel()

    // Controls the “Add New Thread” sheet
    @State private var showingNewThreadSheet = false

    // Controls the “Join Group” prompt for non-members
    @State private var showJoinPrompt = false

    // Bindings for the join-question sheet
    @State private var answerText = ""
    @State private var answerErrorMessage = ""
    @State private var showAnswerErrorAlert = false
    @State private var joinInProgress = false

    var body: some View {
        VStack(spacing: 0) {
            // ── HEADER: Banner + Title + Book Author + Members + Mods ──
            if let group = viewModel.group {
                VStack(alignment: .leading, spacing: 12) {
                    // 1) Banner image (unchanged)
                    AsyncImage(url: URL(string: group.imageUrl)) { phase in
                        switch phase {
                        case .empty:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 200)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .clipped()
                                .cornerRadius(12)
                        case .failure:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.1))
                                .overlay(
                                    Image(systemName: "xmark.octagon.fill")
                                        .foregroundColor(.red)
                                )
                                .frame(height: 200)
                        @unknown default:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 200)
                        }
                    }
                    .padding(.horizontal)

                    // 2) Group title
                    Text(group.title)
                        .font(.largeTitle)
                        .bold()
                        .padding(.horizontal)
                        .multilineTextAlignment(.leading)

                    // 3) Book author
                    Text(group.bookAuthor)
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    // 4) Members row: show letter-avatars for first three memberUIDs
                    HStack(spacing: 12) {
                        ForEach(Array(group.memberIDs.prefix(3)), id: \.self) { memberUID in
                            MemberAvatarView(uid: memberUID)
                        }

                        // If there are more than three members, show “+N more”
                        if group.memberIDs.count > 3 {
                            Text("+\(group.memberIDs.count - 3) more")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                        }

                        Spacer()

                        // 5) “Mods:” list, each tappable → ProfileView(username:)
                        let mods = viewModel.moderatorUsernames
                        if !mods.isEmpty {
                            HStack(spacing: 4) {
                                Text("Mods:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                ForEach(mods, id: \.self) { modName in
                                    NavigationLink(destination: ProfileView(username: modName)) {
                                        Text(modName)
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.trailing)
                        }
                    }
                    .padding(.horizontal)

                    Divider()
                }
            } else {
                // Loading spinner while `viewModel.group` is nil
                VStack {
                    ProgressView("Loading group…")
                        .padding(.top, 40)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // ── THREADS LIST ───────────────────────────────────────────────────────
            if viewModel.group != nil {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // “Add New Thread” button for members
                        if viewModel.isMember {
                            Button {
                                showingNewThreadSheet = true
                            } label: {
                                HStack {
                                    Image(systemName: "square.and.pencil")
                                    Text("Add New Thread")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                        }

                        // Each thread row (avatar, author, content, like/reply buttons)
                        ForEach(viewModel.threads) { thread in
                            ThreadRowView(
                                groupID: groupID,
                                thread: thread,
                                viewModel: viewModel,
                                isMember: viewModel.isMember
                            )
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top)
                }
                .sheet(isPresented: $showingNewThreadSheet) {
                    NewThreadView(groupID: groupID)
                }
            }

            Spacer()

            // ── “Join Group” button for non-members ─────────────────────────────
            if let group = viewModel.group, !viewModel.isMember {
                Button(action: {
                    showJoinPrompt = true
                }) {
                    Text("Join Group")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                }
                .alert(isPresented: $showJoinPrompt) {
                    Alert(
                        title: Text("Join “\(viewModel.group?.title ?? "")”?"),
                        message: Text("Answer the group’s moderation question to join."),
                        primaryButton: .default(Text("Answer")) {
                            showJoinPrompt = true
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
        .navigationTitle("Group Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.bind(to: groupID)
        }
        .onDisappear {
            viewModel.detachListeners()
        }
    }
}

/// ────────────────────────────────────────────────────────────────────────────
/// Renders a single member’s “letter avatar” (first letter of username), on
/// a light-green circle.
/// Fetches the user’s `username` from Firestore once onAppear.
/// ────────────────────────────────────────────────────────────────────────────
private struct MemberAvatarView: View {
    let uid: String
    @State private var username: String = ""
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                // While loading, show a blank (light-green) circle placeholder
                Circle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 30, height: 30)
            } else {
                // Once username is loaded, overlay its first uppercase letter
                let first = String(username.prefix(1)).uppercased()
                Circle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text(first)
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.white)
                    )
            }
        }
        .onAppear {
            let db = Firestore.firestore()
            db.collection("users")
                .document(uid)
                .getDocument { snapshot, error in
                    if let data = snapshot?.data(),
                       let fetched = data["username"] as? String,
                       !fetched.isEmpty {
                        username = fetched
                    } else {
                        username = "?"
                    }
                    isLoading = false
                }
        }
        .padding(.horizontal, 2)
    }
}

/// ────────────────────────────────────────────────────────────────────────────
/// A single row representing one `GroupThread`.
/// • If `thread.authorID` is in `viewModel.moderatorUsernames`,
///   – the entire row’s background becomes a pale green,
///   – and a small “MOD” badge appears next to the author’s name.
/// • Otherwise, it uses the normal styling.
/// ────────────────────────────────────────────────────────────────────────────
struct ThreadRowView: View {
    let groupID: String
    let thread: GroupThread
    @ObservedObject var viewModel: GroupDetailViewModel
    let isMember: Bool

    /// True if the current user’s UID == group.ownerID
    private var isOwner: Bool {
        guard
            let currentUID = Auth.auth().currentUser?.uid,
            let ownerUID   = viewModel.group?.ownerID
        else {
            return false
        }
        return currentUID == ownerUID
    }

    /// True if this thread’s author is a moderator
    private var isModerator: Bool {
        viewModel.moderatorUsernames.contains(thread.authorID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // ── Avatar: light-green circle with first letter of username ──
                let first = String(thread.authorID.prefix(1)).uppercased()
                Circle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(first)
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    // 1) Author’s name → ProfileView(username: thread.authorID)
                    HStack(spacing: 6) {
                        NavigationLink(destination: ProfileView(username: thread.authorID)) {
                            Text(thread.authorID)
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())

                        // 2) If this author is a moderator, show a small “MOD” badge
                        if isModerator {
                            Text("MOD")
                                .font(.caption2)
                                .bold()
                                .foregroundColor(.green)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }

                    Text(thread.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 3) If this user owns the group, show a delete button
                if isOwner {
                    Button {
                        viewModel.deleteThread(groupID: groupID, threadID: thread.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }

            // ── Thread content ──
            Text(thread.content)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            // ── Like & Reply icons (unchanged) ──
            HStack(spacing: 24) {
                Button {
                    if isMember {
                        viewModel.toggleLike(groupID: groupID, threadID: thread.id)
                    }
                } label: {
                    Image(systemName: (thread.likeCount > 0) ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundColor(
                            isMember
                                ? (thread.likeCount > 0 ? .red : .gray)
                                : .gray.opacity(0.5)
                        )
                }
                .disabled(!isMember)

                NavigationLink(destination: ThreadDetailView(groupID: groupID, thread: thread)) {
                    Image(systemName: "bubble.right")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
            }
            .font(.title3)

            // ── “X likes · Y replies” footer ──
            HStack(spacing: 8) {
                Text("\(thread.likeCount) likes")
                Text("·")
                Text("\(thread.replyCount) replies")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            Divider()
        }
        .padding()
        // ── If the author is a moderator, use a pale-green background; otherwise default ──
        .background(
            isModerator
                ? Color.green.opacity(0.1)
                : Color(UIColor.secondarySystemBackground)
        )
        .cornerRadius(12)
    }
}
