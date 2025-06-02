//
//  GroupPageView.swift
//  BookClubB
//
//  Created by Irene Lin on 5/31/25.
//  Updated 6/11/25 to also add the joined group’s ID into the user’s `groupIDs` array.
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

    // Controls the “Create Group” sheet
    @State private var showingCreateGroup: Bool = false

    // For the “answer the question” sheet:
    @State private var groupToAnswer: BookGroup? = nil
    @State private var answerText: String = ""
    @State private var answerErrorMessage: String = ""
    @State private var showAnswerErrorAlert: Bool = false

    // ─── Computed properties ──────────────────────────────────────────────────
    /// UID of the currently signed‐in user (or empty string if none)
    private var currentUserID: String {
        Auth.auth().currentUser?.uid ?? ""
    }

    /// All groups matching the search text (regardless of membership)
    private var matchingGroups: [BookGroup] {
        let lower = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if lower.isEmpty {
            return allGroups
        }
        return allGroups.filter { $0.title.lowercased().contains(lower) }
    }

    /// Of those matching groups, only those the user does NOT already belong to
    private var recommendedGroups: [BookGroup] {
        matchingGroups.filter { !($0.memberIDs.contains(currentUserID)) }
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                // ─── Page Title ───────────────────────────────────────────────
                Text("Groups")
                    .font(.largeTitle)
                    .bold()
                    .padding(.horizontal)

                // ─── Search Bar ────────────────────────────────────────────────
                TextField("Search all groups", text: $searchText)
                    .padding(12)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)

                // ─── “New Group” Card ────────────────────────────────────────
                Button {
                    showingCreateGroup = true
                } label: {
                    HStack {
                        Text("New Group")
                            .font(.headline)
                            .foregroundColor(.blue)
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.systemGray6))
                    )
                    .padding(.horizontal)
                }

                // ─── “Your Groups” Section ──────────────────────────────────
                SectionHeaderView(title: "Your Groups")
                    .padding(.horizontal)

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

                // ─── “Groups You Might Be Interested In” Section ───────────
                SectionHeaderView(title: "Groups You Might Be Interested In")
                    .padding(.horizontal)

                if recommendedGroups.isEmpty {
                    Text("No recommendations at the moment.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(recommendedGroups) { group in
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
                        .padding(.top)
                    }
                }

                Spacer()
            }
            .padding(.top)
            .navigationBarHidden(true)
            .alert(isPresented: $showErrorAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $showingCreateGroup, onDismiss: fetchAllGroups) {
                CreateGroupView()
            }
            // ─── Inline “Answer Group Question” sheet ─────────────────────
            .sheet(item: $groupToAnswer) { group in
                NavigationView {
                    VStack(spacing: 20) {
                        // Title
                        Text("Answer to join \"\(group.title)\"")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.top, 16)

                        // The moderation question itself
                        Text(group.moderationQuestion)
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 16)

                        // TextField for the user’s answer
                        TextField("Your answer", text: $answerText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal, 16)

                        // Show any validation error
                        if showAnswerErrorAlert, !answerErrorMessage.isEmpty {
                            Text(answerErrorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(.horizontal, 16)
                        }

                        Spacer()

                        // Buttons: Cancel & Submit
                        HStack(spacing: 16) {
                            Button(action: {
                                // User tapped “Cancel”
                                groupToAnswer = nil
                                answerText = ""
                                answerErrorMessage = ""
                                showAnswerErrorAlert = false
                            }) {
                                Text("Cancel")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 20)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }

                            Spacer()

                            Button(action: {
                                // User tapped “Submit”
                                joinInProgress = true
                                validateAnswerAndJoin(group: group)
                            }) {
                                if joinInProgress {
                                    ProgressView()
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 20)
                                } else {
                                    Text("Submit")
                                        .font(.body)
                                        .foregroundColor(.white)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 20)
                                }
                            }
                            .background(joinInProgress ? Color.gray.opacity(0.6) : Color.blue)
                            .cornerRadius(8)
                            .disabled(joinInProgress)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    .navigationTitle("Join Group")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            .onAppear(perform: fetchAllGroups)
        }
    }

    // ───────────────────────────────────────────────────────────────────────────
    /// Fetch all groups from Firestore, sorted by creation date.
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
    /// Validates the user’s answer. If correct, adds them to both the group’s
    /// memberIDs array and the user’s groupIDs array in Firestore.
    private func validateAnswerAndJoin(group: BookGroup) {
        let trimmedInput = answerText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let trimmedCorrect = group.correctAnswer
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if trimmedInput == trimmedCorrect {
            // 1) Add current user to the group’s memberIDs AND add group to user’s groupIDs
            guard let user = Auth.auth().currentUser else {
                answerErrorMessage = "You must be signed in to join."
                showAnswerErrorAlert = true
                joinInProgress = false
                groupToAnswer = nil
                return
            }

            let db = Firestore.firestore()
            let groupRef = db.collection("groups").document(group.id)
            let userRef = db.collection("users").document(user.uid)

            // Use a batch to update both documents atomically
            let batch = db.batch()

            // a) Update the group document:
            batch.updateData([
                "memberIDs": FieldValue.arrayUnion([user.uid]),
                "updatedAt": Timestamp(date: Date())
            ], forDocument: groupRef)

            // b) Update the user document:
            batch.updateData([
                "groupIDs": FieldValue.arrayUnion([group.id])
            ], forDocument: userRef)

            batch.commit { err in
                joinInProgress = false
                if let err = err {
                    errorMessage = "Could not join: \(err.localizedDescription)"
                    showErrorAlert = true
                } else {
                    // Refresh so “Your Groups” immediately shows the newly joined group
                    fetchAllGroups()
                }
                groupToAnswer = nil
            }
        } else {
            answerErrorMessage = "That’s not correct. Please try again."
            showAnswerErrorAlert = true
            joinInProgress = false
        }
    }
}


// ───────────────────────────────────────────────────────────────────────────────
// MARK: – GroupCardView
// A reusable “card” for displaying a BookGroup in a horizontal scroll.
// ───────────────────────────────────────────────────────────────────────────────
struct GroupCardView: View {
    let group: BookGroup

    var body: some View {
        VStack(spacing: 8) {
            // Cover Image
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

            // Group title
            Text(group.title)
                .font(.caption)
                .multilineTextAlignment(.center)
                .frame(width: 140)
        }
    }
}


// ───────────────────────────────────────────────────────────────────────────────
// MARK: – SectionHeaderView
// A small helper to render section titles (e.g. “Your Groups”).
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

    // Bindings from parent so we can control the join‐sheet and error state:
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
