//
//  GroupPageView.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//  Updated 6/3/25 to remove the `if let createdAt` on a non‐optional Date.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct GroupPageView: View {
    // ─── State variables ─────────────────────────────────────────────────────
    @State private var allGroups: [BookGroup] = []
    @State private var searchText: String = ""
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var joinInProgress: Bool = false

    // For the “answer the question” sheet:
    @State private var groupToAnswer: BookGroup? = nil
    @State private var answerText: String = ""
    @State private var answerErrorMessage: String = ""
    @State private var showAnswerErrorAlert: Bool = false

    // ─── Computed properties ──────────────────────────────────────────────────
    private var currentUserID: String {
        Auth.auth().currentUser?.uid ?? ""
    }

    private var matchingGroups: [BookGroup] {
        let lower = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower.isEmpty {
            return allGroups
        }
        return allGroups.filter { $0.title.lowercased().contains(lower) }
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                // ─── Search Bar ────────────────────────────────────────────────
                TextField("Search groups…", text: $searchText)
                    .padding(12)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.top, 8)

                // ─── “Your Groups” (horizontal list) ─────────────────────────
                SectionHeaderView(title: "Your Groups")
                    .padding(.horizontal)
                    .padding(.top, 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(allGroups.filter { $0.memberIDs.contains(currentUserID) }) { group in
                            NavigationLink(destination: GroupDetailView(groupID: group.id)) {
                                GroupCardView(group: group)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 240)

                // ─── “Groups You Might Be Interested In” (vertical list) ─────
                SectionHeaderView(title: "Groups You Might Be Interested In")
                    .padding(.horizontal)
                    .padding(.top, 16)

                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(matchingGroups) { group in
                            SearchResultRow(
                                group: group,
                                currentUserID: currentUserID,
                                joinInProgress: $joinInProgress,
                                groupToAnswer: $groupToAnswer,
                                errorMessage: $errorMessage,
                                showErrorAlert: $showErrorAlert
                            )
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Groups")
            .onAppear { fetchAllGroups() }
            .alert(isPresented: $showErrorAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            // ─── Present the sheet to answer the question ─────────────────
            .sheet(item: $groupToAnswer) { group in
                AnswerGroupQuestionView(
                    group: group,
                    answerText: $answerText,
                    answerErrorMessage: $answerErrorMessage,
                    showAnswerErrorAlert: $showAnswerErrorAlert,
                    joinInProgress: $joinInProgress
                ) {
                    // Called when the user types the correct answer:
                    joinGroupAfterAnswer(group: group)
                } onCancel: {
                    groupToAnswer = nil
                }
                // Clear answer fields when the sheet appears:
                .onAppear {
                    answerText = ""
                    answerErrorMessage = ""
                    showAnswerErrorAlert = false
                }
            }
        }
    }

    // ───────────────────────────────────────────────────────────────────────────
    /// Fetch all groups from Firestore, sorted by creation date
    private func fetchAllGroups() {
        let db = Firestore.firestore()
        db.collection("groups")
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, err in
                if let err = err {
                    errorMessage = "Failed to load groups: \(err.localizedDescription)"
                    showErrorAlert = true
                } else {
                    allGroups = snapshot?.documents.compactMap { doc in
                        BookGroup.fromDictionary(doc.data(), id: doc.documentID)
                    } ?? []
                }
            }
    }

    // ───────────────────────────────────────────────────────────────────────────
    /// Called once the user correctly answers the question.
    private func joinGroupAfterAnswer(group: BookGroup) {
        guard let user = Auth.auth().currentUser else {
            answerErrorMessage = "You must be signed in to join."
            showAnswerErrorAlert = true
            groupToAnswer = nil
            return
        }

        joinInProgress = true
        let db = Firestore.firestore()
        let groupRef = db.collection("groups").document(group.id)

        groupRef.updateData([
            "memberIDs": FieldValue.arrayUnion([user.uid]),
            "updatedAt": Timestamp(date: Date())
        ]) { err in
            joinInProgress = false
            if let err = err {
                errorMessage = "Could not join: \(err.localizedDescription)"
                showErrorAlert = true
            } else {
                // Refresh so the “Joined” state updates
                fetchAllGroups()
            }
            groupToAnswer = nil
        }
    }
}


// ───────────────────────────────────────────────────────────────────────────────
// MARK: – SectionHeaderView
// A small helper to render section titles (“Your Groups”, etc.)
// ───────────────────────────────────────────────────────────────────────────────
fileprivate struct SectionHeaderView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
    }
}


// ───────────────────────────────────────────────────────────────────────────────
// MARK: – GroupCardView
// Renders a single “card” in the horizontal “Your Groups” scroller.
// ───────────────────────────────────────────────────────────────────────────────
fileprivate struct GroupCardView: View {
    let group: BookGroup

    var body: some View {
        VStack {
            AsyncImage(url: URL(string: group.imageUrl)) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 140, height: 200)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 200)
                        .clipped()
                        .cornerRadius(8)
                case .failure:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.1))
                        .overlay(
                            Image(systemName: "photo.fill")
                                .foregroundColor(.red)
                        )
                        .frame(width: 140, height: 200)
                @unknown default:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 140, height: 200)
                }
            }

            Text(group.title)
                .font(.caption)
                .multilineTextAlignment(.center)
                .frame(width: 140)
        }
    }
}


// ───────────────────────────────────────────────────────────────────────────────
// MARK: – SearchResultRow
// Renders one row in the vertical “Groups You Might Be Interested In” list.
// ───────────────────────────────────────────────────────────────────────────────
fileprivate struct SearchResultRow: View {
    let group: BookGroup
    let currentUserID: String

    // Bindings from parent:
    @Binding var joinInProgress: Bool
    @Binding var groupToAnswer: BookGroup?
    @Binding var errorMessage: String
    @Binding var showErrorAlert: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
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

                VStack(alignment: .leading, spacing: 4) {
                    Text(group.title)
                        .font(.headline)
                    Text("by \(group.bookAuthor)")  // <-- correct field name
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if group.memberIDs.contains(currentUserID) {
                    Text("Joined")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.green, lineWidth: 1)
                        )
                } else {
                    Button {
                        // Prepare to present the sheet; clear answer fields on sheet appear
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

            // Directly use group.createdAt (non-optional Date)
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


// ───────────────────────────────────────────────────────────────────────────────
// MARK: – AnswerGroupQuestionView
// Presented as a sheet to ask the moderation question (case‐insensitive).
// ───────────────────────────────────────────────────────────────────────────────
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
