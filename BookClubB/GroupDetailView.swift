//
//  GroupDetailView.swift
//  BookClubB
//
//  Created by Irene Lin on 5/31/25.
//  Updated 6/10/25 to allow group‐owners to delete posts and show all mods.
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

    // Bindings for the join‐question sheet
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

                        if !viewModel.moderatorUsernames.isEmpty {
                            Text("Mods: \(viewModel.moderatorUsernames.joined(separator: ", "))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
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

            // ── THREAD LIST (visible to everyone) ────────────────────────────
            ScrollView {
                LazyVStack(spacing: 16) {
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
                .padding(.vertical)
            }

            Divider()

            // ── BOTTOM BUTTON AREA: “Add Post” if member, else “Join Group” ──
            if viewModel.isMember {
                Button(action: {
                    showingNewThreadSheet = true
                }) {
                    Text("Add Post")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                }
                .sheet(isPresented: $showingNewThreadSheet) {
                    NewThreadView(groupID: groupID)
                }
            } else {
                Button(action: {
                    showJoinPrompt = true
                }) {
                    Text("Join Group to Post & Like")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                }
                .sheet(isPresented: $showJoinPrompt) {
                    // We only present this when group != nil, so force‐unwrap is safe:
                    AnswerGroupQuestionView(
                        group: viewModel.group!,
                        answerText: $answerText,
                        answerErrorMessage: $answerErrorMessage,
                        showAnswerErrorAlert: $showAnswerErrorAlert,
                        joinInProgress: $joinInProgress
                    ) {
                        joinAfterAnswer()
                    } onCancel: {
                        showJoinPrompt = false
                    }
                    .onAppear {
                        answerText = ""
                        answerErrorMessage = ""
                        showAnswerErrorAlert = false
                    }
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

    // ─────────────────────────────────────────────────────────────────────────
    /// Called when the user submits the correct answer in AnswerGroupQuestionView.
    /// Adds their UID to “memberIDs” in Firestore and re‐binds.
    private func joinAfterAnswer() {
        guard let group = viewModel.group else {
            showJoinPrompt = false
            return
        }
        guard let currentUser = Auth.auth().currentUser else {
            answerErrorMessage = "You must be signed in to join."
            showAnswerErrorAlert = true
            return
        }

        joinInProgress = true
        let db = Firestore.firestore()
        let groupRef = db.collection("groups").document(groupID)

        groupRef.updateData([
            "memberIDs": FieldValue.arrayUnion([currentUser.uid]),
            "updatedAt": Timestamp(date: Date())
        ]) { err in
            joinInProgress = false
            if let err = err {
                answerErrorMessage = "Failed to join: \(err.localizedDescription)"
                showAnswerErrorAlert = true
            } else {
                // Re-bind so that isMember flips to true
                viewModel.bind(to: groupID)
                showJoinPrompt = false
            }
        }
    }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// A single “thread” row. Shows authorID, timestamp, content, like/reply icons,
/// and (if the current user is the group owner) a red “trash” button
/// that calls `viewModel.deleteThread(...)`.
/// ─────────────────────────────────────────────────────────────────────────────
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
            // ── Author + Timestamp + (Owner‐only “trash” button) ──
            HStack(spacing: 12) {
                // Placeholder circle for an avatar (GroupThread has no avatarUrl)
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(thread.authorID)             // authorID as “username”
                        .font(.subheadline)
                        .bold()
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

/// ─────────────────────────────────────────────────────────────────────────────
/// A sheet that asks the group’s moderation question. If the user’s trimmed,
/// lowercased answer matches `group.correctAnswer`, calls `onCorrectAnswer()`.
/// Otherwise, shows an alert.
/// ─────────────────────────────────────────────────────────────────────────────
fileprivate struct AnswerGroupQuestionView: View {
    let group: BookGroup

    @Binding var answerText: String
    @Binding var answerErrorMessage: String
    @Binding var showAnswerErrorAlert: Bool
    @Binding var joinInProgress: Bool

    var onCorrectAnswer: () -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("To join “\(group.title)”, answer:")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text(group.moderationQuestion)
                    .font(.subheadline)
                    .italic()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                TextField("Your answer", text: $answerText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                if joinInProgress {
                    ProgressView()
                        .padding(.top, 8)
                }

                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("Answer to Join")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    onCancel()
                },
                trailing: Button("Submit") {
                    checkAnswer()
                }
                .disabled(
                    answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || joinInProgress
                )
            )
            .alert(isPresented: $showAnswerErrorAlert) {
                Alert(
                    title: Text("Incorrect Answer"),
                    message: Text(answerErrorMessage),
                    dismissButton: .default(Text("Try Again"))
                )
            }
        }
    }

    private func checkAnswer() {
        let trimmedInput = answerText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let trimmedCorrect = group.correctAnswer
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if trimmedInput == trimmedCorrect {
            onCorrectAnswer()
        } else {
            answerErrorMessage = "That’s not correct. Please try again."
            showAnswerErrorAlert = true
        }
    }
}
