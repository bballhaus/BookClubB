//
//  GroupDetailView.swift
//  BookClubB
//
//  Created by YourName on 6/1/25.
//  Updated 6/3/25 to remove duplicate type declarations and reference existing models.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct GroupDetailView: View {
    let groupID: String

    // Use the already–defined ViewModel (GroupDetailViewModel.swift :contentReference[oaicite:1]{index=1})
    @StateObject private var viewModel = GroupDetailViewModel()

    // Controls presentation of the “New Thread” sheet (shown only if isMember)
    @State private var showingNewThreadSheet: Bool = false

    // When not yet a member, we ask the moderation question:
    @State private var answerText: String = ""
    @State private var showAnswerErrorAlert: Bool = false
    @State private var answerErrorMessage: String = ""
    @State private var joinInProgress: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ── Wait until the group data is loaded ──
            if let group = viewModel.group {
                // ── Header: group image + title + member‐count preview ──
                VStack(alignment: .leading, spacing: 8) {
                    // Cover image (using group.imageUrl from BookGroup.swift :contentReference[oaicite:2]{index=2})
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

                    // Show up to 3 placeholder circles for existing members
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

                    Divider().padding(.horizontal)
                }

                // ── If the user is not yet a member and has not answered, show the moderation question ──
                if !viewModel.isMember && !viewModel.hasAnswered {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Moderation Question:")
                            .font(.headline)
                            .padding(.horizontal)

                        Text(group.moderationQuestion)
                            .font(.body)
                            .padding(.horizontal)

                        TextField("Your answer", text: $answerText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)

                        Button(action: submitAnswer) {
                            HStack {
                                Spacer()
                                if joinInProgress {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .padding(.vertical, 8)
                                } else {
                                    Text("Submit Answer")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.vertical, 8)
                                }
                                Spacer()
                            }
                            .background(joinInProgress ? Color.gray : Color.blue)
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }
                        .disabled(answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || joinInProgress)
                    }
                }

                // ── If they have answered but Firestore hasn’t updated isMember yet ──
                else if !viewModel.isMember && viewModel.hasAnswered {
                    Text("Your answer was submitted. Waiting for approval.")
                        .italic()
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 20)
                }

                // ── If the user _is_ a member, show the thread list + “Add Post” ──
                else if viewModel.isMember {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Posts")
                            .font(.headline)
                            .padding(.horizontal)

                        if viewModel.threads.isEmpty {
                            Spacer()
                            Text("No threads yet. Be the first to post!")
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            Spacer()
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 16) {
                                    // Use the existing ThreadModel and toggleLike from GroupDetailViewModel :contentReference[oaicite:3]{index=3}
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
                        }

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

                Spacer(minLength: 20)
            }
            // ── If the group data is not yet loaded, show a spinner ──
            else {
                VStack {
                    ProgressView("Loading group…")
                        .padding(.top, 40)
                    Text("Please wait…")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.bind(to: groupID)
        }
        .alert(isPresented: $showAnswerErrorAlert) {
            Alert(
                title: Text("Incorrect Answer"),
                message: Text(answerErrorMessage),
                dismissButton: .default(Text("Try Again"))
            )
        }
    }

    // ───────────────────────────────────────────────────────────────────────────
    /// Called when the user taps “Submit Answer.” Performs a case‐insensitive check
    /// against `group.correctAnswer` (from BookGroup.swift :contentReference[oaicite:4]{index=4}), and if correct,
    /// adds the current user’s UID to `memberIDs`. Otherwise, shows an alert and lets them try again.
    private func submitAnswer() {
        guard let group = viewModel.group else { return }
        guard let currentUser = Auth.auth().currentUser else {
            answerErrorMessage = "You must be signed in to join."
            showAnswerErrorAlert = true
            return
        }

        // Trim & lowercase both strings for a case‐insensitive comparison
        let trimmedInput = answerText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let trimmedCorrect = group.correctAnswer
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if trimmedInput != trimmedCorrect {
            answerErrorMessage = "That’s not correct. Please try again."
            showAnswerErrorAlert = true
            return
        }

        // If the answer is correct, update Firestore → add the user to memberIDs
        joinInProgress = true
        let db = Firestore.firestore()
        let groupRef = db.collection("groups").document(groupID)

        groupRef.updateData([
            "memberIDs": FieldValue.arrayUnion([currentUser.uid]),
            "updatedAt": Timestamp(date: Date())
        ]) { err in
            DispatchQueue.main.async {
                self.joinInProgress = false
                if let err = err {
                    answerErrorMessage = "Failed to join: \(err.localizedDescription)"
                    showAnswerErrorAlert = true
                } else {
                    // Once Firestore updates, the listener in GroupDetailViewModel
                    // will set viewModel.isMember = true, causing the UI to switch over.
                    viewModel.bind(to: groupID)
                }
            }
        }
    }
}


/// ───────────────────────────────────────────────────────────────────────────────
/// A single “post” (thread) row. Displays avatar, username, content, and the “like”
/// + “reply” icons. Tapping “like” calls viewModel.toggleLike(...) (from GroupDetailViewModel :contentReference[oaicite:5]{index=5}).
/// Tapping the bubble navigates to ThreadDetailView.
/// ───────────────────────────────────────────────────────────────────────────────
struct ThreadView: View {
    let groupID: String
    let thread: ThreadModel
    @ObservedObject var viewModel: GroupDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Avatar + username + timestamp
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

            // Thread content
            Text(thread.content)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            // Like & Reply icons
            HStack(spacing: 24) {
                Button {
                    viewModel.toggleLike(groupID: groupID, threadID: thread.id)
                } label: {
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

                NavigationLink(destination: ThreadDetailView(groupID: groupID, thread: thread)) {
                    Image(systemName: "bubble.right")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
            }
            .font(.title3)

            // Footer: “X likes · Y replies”
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
