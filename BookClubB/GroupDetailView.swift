//
//  GroupDetailView.swift
//  BookClubB
//
//  Created by Irene Lin on 5/31/25.
//  Updated 6/4/25: show ownerUsername and fix thread display.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct GroupDetailView: View {
    let groupID: String

    @StateObject private var viewModel = GroupDetailViewModel()

    // Controls “Add Post” sheet (members only)
    @State private var showingNewThreadSheet: Bool = false

    // Controls “Join Group” sheet (non-members)
    @State private var showJoinPrompt: Bool = false

    // Bindings for the “AnswerGroupQuestionView”
    @State private var answerText: String = ""
    @State private var answerErrorMessage: String = ""
    @State private var showAnswerErrorAlert: Bool = false
    @State private var joinInProgress: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // ── HEADER: Image + Title + Book Author + Mod Info ────────────
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

                    // 4) Row: up to 3 member circles + “X members” + Spacer + “Mod: ownerUsername”
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

                        // Always show “Mod: <ownerUsername>” once fetched
                        if !viewModel.ownerUsername.isEmpty {
                            Text("Mod: \(viewModel.ownerUsername)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    Divider()
                }
            } else {
                // Spinner while group is loading
                VStack {
                    ProgressView("Loading group…")
                        .padding(.top, 40)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // ── THREAD LIST (visible to all) ────────────────────────────────
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

            // ── BOTTOM BUTTON AREA ───────────────────────────────────────────
            if viewModel.isMember {
                // Members see “Add Post”
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
                // Non-members see “Join Group to Post & Like”
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
                    // Safe to force‐unwrap because group != nil here
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

    // ───────────────────────────────────────────────────────────────────────────
    /// Called after the user correctly answers the join‐question.
    /// Adds currentUID to Firestore “groups/{groupID}.memberIDs” and re‐binds.
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
                // Immediately re-bind so isMember becomes true
                viewModel.bind(to: groupID)
                showJoinPrompt = false
            }
        }
    }
}

/// ───────────────────────────────────────────────────────────────────────────────
/// A single “thread” row. Shows authorID, timestamp, content, like/reply icons.
/// If isMember == false, the heart is gray and disabled.
/// ───────────────────────────────────────────────────────────────────────────────
struct ThreadRowView: View {
    let groupID: String
    let thread: GroupThread
    @ObservedObject var viewModel: GroupDetailViewModel
    let isMember: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ── Author + Timestamp ──
            HStack(spacing: 12) {
                // Placeholder circle (no avatarUrl on GroupThread)
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
            }

            // ── Thread content ──
            Text(thread.content)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            // ── Like & Reply icons ──
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

/// ───────────────────────────────────────────────────────────────────────────────
/// A sheet view that asks the user the group’s moderation question.
/// If the trimmed + lowercased answer matches `group.correctAnswer`, calls `onCorrectAnswer()`.
/// Otherwise, shows an “Incorrect Answer” alert.
/// ───────────────────────────────────────────────────────────────────────────────
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
