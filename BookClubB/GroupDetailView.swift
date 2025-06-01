//
//  GroupDetailView.swift
//  BookClubB
//
//  Created by Irene Lin on 5/31/25.
//  Updated 6/4/25 to fix join flow so UI updates immediately after answering.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct GroupDetailView: View {
    let groupID: String

    @StateObject private var viewModel = GroupDetailViewModel()

    // Controls presentation of the “New Thread” sheet (members only)
    @State private var showingNewThreadSheet: Bool = false

    // Controls presentation of the “Join” sheet (when not a member)
    @State private var showJoinPrompt: Bool = false

    // Bindings for AnswerGroupQuestionView
    @State private var answerText: String = ""
    @State private var answerErrorMessage: String = ""
    @State private var showAnswerErrorAlert: Bool = false
    @State private var joinInProgress: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // ── Header Area ────────────────────────────────────────────
            if let group = viewModel.group {
                VStack(alignment: .leading, spacing: 12) {
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

                    Text(group.title)
                        .font(.title)
                        .bold()
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 8) {
                        ForEach(Array(group.memberIDs.prefix(3)), id: \.self) { _ in
                            Circle()
                                .fill(Color.gray.opacity(0.4))
                                .frame(width: 24, height: 24)
                        }
                        Text("\(group.memberIDs.count) members")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
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
                // We deliberately do NOT return here, so that the rest of the VStack still exists.
            }

            // ── Thread List (always visible) ────────────────────────────
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

            // ── Bottom Button Area ──────────────────────────────────────
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
                    // Force‐unwrap safe because we only present if group != nil
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
                        // Reset fields whenever this sheet appears
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
    /// Called once the user types the correct answer in AnswerGroupQuestionView.
    /// Writes their UID into Firestore ⟶ "memberIDs". Then immediately appends
    /// currentUser.uid to `viewModel.group?.memberIDs` so that `viewModel.isMember`
    /// flips to true right away (without waiting for Firestore to push down a new snapshot).
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
                // If Firestore write fails
                answerErrorMessage = "Failed to join: \(err.localizedDescription)"
                showAnswerErrorAlert = true
            } else {
                // 1) Locally append the UID so viewModel.isMember == true immediately
                if !viewModel.group!.memberIDs.contains(currentUser.uid) {
                    viewModel.group!.memberIDs.append(currentUser.uid)
                }
                // 2) Also re‐bind to pick up any other document changes
                viewModel.bind(to: groupID)

                // 3) Dismiss the sheet
                showJoinPrompt = false
            }
        }
    }
}


/// ───────────────────────────────────────────────────────────────────────────────
/// A single thread row. Shows avatar, username, content, and the “like” + “reply” icons.
/// For non‐members, the heart is gray and disabled; reply still works.
/// ───────────────────────────────────────────────────────────────────────────────
struct ThreadRowView: View {
    let groupID: String
    let thread: ThreadModel
    @ObservedObject var viewModel: GroupDetailViewModel
    let isMember: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ── Avatar + username + timestamp ──
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

            // ── Content ──
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
                    Image(systemName: thread.isLikedByCurrentUser ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundColor(
                            isMember
                                ? (thread.isLikedByCurrentUser ? .red : .gray)
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

            // ── Footer ──
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


/// ───────────────────────────────────────────────────────────────────────────────
/// Presented as a sheet to ask the moderation question (case‐insensitive).
/// If input matches `correctAnswer`, calls `onCorrectAnswer()`. Otherwise shows an alert.
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
