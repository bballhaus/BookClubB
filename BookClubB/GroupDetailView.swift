//
//  GroupDetailView.swift
//  BookClubB
//
//  Created by Irene Lin on 5/31/25.
//  Updated 6/11/25 to remove `username:` arguments from ProfileView
//  and to simplify the “Mods:” HStack so the compiler can type-check.
//
//  Now tapping any username just opens the personal ProfileView().
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct GroupDetailView: View {
    let groupID: String

    @StateObject private var viewModel = GroupDetailViewModel()

    // “Add Post” sheet for members
    @State private var showingNewThreadSheet: Bool = false

    // “Join Group” sheet for non-members
    @State private var showJoinPrompt: Bool = false

    // Bindings for the join-question sheet
    @State private var answerText: String = ""
    @State private var answerErrorMessage: String = ""
    @State private var showAnswerErrorAlert: Bool = false
    @State private var joinInProgress: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // ── HEADER: Banner + Title + Book Author + Members + Mods ──
            if let group = viewModel.group {
                VStack(alignment: .leading, spacing: 12) {
                    // 1) Banner image
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

                    // 4) Row: up to 3 member circles + “X members” + Spacer + “Mods: …”
                    HStack(spacing: 8) {
                        ForEach(Array(group.memberIDs.prefix(3)), id: \.self) { _ in
                            Circle()
                                .fill(Color.gray.opacity(0.4))
                                .frame(width: 24, height: 24)
                        }
                        Text("\(group.memberIDs.count) members")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()

                        // Extract moderator list into a local constant to help the type-checker
                        let mods = viewModel.moderatorUsernames
                        if !mods.isEmpty {
                            HStack(spacing: 4) {
                                Text("Mods:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                // Now simply call ProfileView() without passing `username:`
                                ForEach(mods, id: \.self) { modName in
                                    NavigationLink(destination: ProfileView()) {
                                        Text(modName)
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                    }
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

            // ─────────────────────────────────────────────────────────────────────────
            // (The rest of GroupDetailView, unchanged, goes here…)
            // Threads list, New Thread button, Join question sheet trigger, etc.
            // ─────────────────────────────────────────────────────────────────────────

            if let group = viewModel.group {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // If the user is a member, allow “Add Post”:
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

            // ── If the user is not a member, show a “Join Group” prompt button ──
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
                            // Showing the sheet
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

// ───────────────────────────────────────────────────────────────────────────────
// A single “thread” row. Shows authorID, timestamp, content, like/reply icons,
// and (if the current user is the group owner) a red “trash” button.
struct ThreadRowView: View {
    let groupID: String
    let thread: GroupThread
    @ObservedObject var viewModel: GroupDetailViewModel
    let isMember: Bool

    /// True if the currently signed-in user’s UID equals the group’s ownerID
    private var isOwner: Bool {
        guard let currentUID = Auth.auth().currentUser?.uid,
              let ownerUID = viewModel.group?.ownerID
        else {
            return false
        }
        return currentUID == ownerUID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ── Author + Timestamp + (Owner-only “trash” button) ──
            HStack(spacing: 12) {
                // Placeholder circle for an avatar (GroupThread has no avatarUrl)
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    // Now just open ProfileView() without arguments
                    NavigationLink(destination: ProfileView()) {
                        Text(thread.authorID)
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.blue)
                    }
                    Text(thread.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Only show a red trash icon if this user is the group’s owner:
                if isOwner {
                    Button {
                        viewModel.deleteThread(groupID: groupID, threadID: thread.id)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.title3)
                    }
                    // Use a borderless style so it doesn’t hijack row taps:
                    .buttonStyle(BorderlessButtonStyle())
                }
            }

            // ── Thread Content ──
            Text(thread.content)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            // ── Like & Reply Icons ──
            HStack(spacing: 24) {
                Button {
                    if isMember {
                        viewModel.toggleLike(groupID: groupID, threadID: thread.id)
                    }
                } label: {
                    Image(
                        systemName: thread.likeCount > 0 ? "heart.fill" : "heart"
                    )
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
    }
}

// ───────────────────────────────────────────────────────────────────────────────
// MARK: – SectionHeaderView
// A small helper to render section titles (e.g., “Your Groups”).
// ───────────────────────────────────────────────────────────────────────────────
fileprivate struct SectionHeaderView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.leading, 16)
    }
}

// ───────────────────────────────────────────────────────────────────────────────
// MARK: – SearchResultRow
// Renders one row under “Groups You Might Be Interested In.” Excludes any group
// the user already belongs to. Tapping the image navigates to GroupDetailView.
// ───────────────────────────────────────────────────────────────────────────────
fileprivate struct SearchResultRow: View {
    let group: BookGroup
    let currentUserID: String

    // Bindings from parent so we can control the join-sheet and error state:
    @Binding var joinInProgress: Bool
    @Binding var groupToAnswer: BookGroup?
    @Binding var errorMessage: String
    @Binding var showErrorAlert: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Tappable group image
                NavigationLink(destination: GroupDetailView(groupID: group.id)) {
                    AsyncImage(url: URL(string: group.imageUrl)) { phase in
                        switch phase {
                        case .empty:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 80, height: 80)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipped()
                                .cornerRadius(8)
                        case .failure:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.1))
                                .overlay(
                                    Image(systemName: "photo.fill")
                                        .foregroundColor(.red)
                                )
                                .frame(width: 80, height: 80)
                        @unknown default:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 80, height: 80)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(group.title)
                        .font(.headline)
                    Text("by \(group.bookAuthor)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // If already a member, show “Joined,” else show “Join” button
                if group.memberIDs.contains(currentUserID) {
                    Text("Joined")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.green, lineWidth: 1)
                        )
                } else {
                    Button {
                        groupToAnswer = group
                    } label: {
                        Text(joinInProgress && groupToAnswer?.id == group.id
                               ? "Joining…"
                               : "Join")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .disabled(joinInProgress)
                }
            }

            HStack(spacing: 8) {
                Text("\(group.memberIDs.count) members")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("·")
                Text(group.createdAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
}
