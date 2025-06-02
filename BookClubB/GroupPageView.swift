//
//  GroupPageView.swift
//  BookClubB
//
//  Created by Irene Lin on 5/31/25.
//  Updated to also add the joined group’s ID into the user’s `groupIDs` array.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct GroupPageView: View {

    @State private var allGroups: [BookGroup] = []
    @State private var searchText: String = ""
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var joinInProgress: Bool = false

    @State private var showingCreateGroup: Bool = false

    @State private var groupToAnswer: BookGroup? = nil
    @State private var answerText: String = ""
    @State private var answerErrorMessage: String = ""
    @State private var showAnswerErrorAlert: Bool = false

 
    private var currentUserID: String {
        Auth.auth().currentUser?.uid ?? ""
    }

    private var matchingGroups: [BookGroup] {
        let lower = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if lower.isEmpty {
            return allGroups
        }
        return allGroups.filter { $0.title.lowercased().contains(lower) }
    }

    private var recommendedGroups: [BookGroup] {
        matchingGroups.filter { !($0.memberIDs.contains(currentUserID)) }
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Groups")
                    .font(.largeTitle)
                    .bold()
                    .padding(.horizontal)

                TextField("Search all groups", text: $searchText)
                    .padding(12)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)

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
            .sheet(item: $groupToAnswer) { group in
                NavigationView {
                    VStack(spacing: 20) {
                        // Title
                        Text("Answer to join \"\(group.title)\"")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.top, 16)

                        Text(group.moderationQuestion)
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 16)

                        TextField("Your answer", text: $answerText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal, 16)

                        if showAnswerErrorAlert, !answerErrorMessage.isEmpty {
                            Text(answerErrorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(.horizontal, 16)
                        }

                        Spacer()

                        HStack(spacing: 16) {
                            Button(action: {
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

    
    private func validateAnswerAndJoin(group: BookGroup) {
        let trimmedInput = answerText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let trimmedCorrect = group.correctAnswer
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if trimmedInput == trimmedCorrect {
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

            let batch = db.batch()

            batch.updateData([
                "memberIDs": FieldValue.arrayUnion([user.uid]),
                "updatedAt": Timestamp(date: Date())
            ], forDocument: groupRef)

            batch.updateData([
                "groupIDs": FieldValue.arrayUnion([group.id])
            ], forDocument: userRef)

            batch.commit { err in
                joinInProgress = false
                if let err = err {
                    errorMessage = "Could not join: \(err.localizedDescription)"
                    showErrorAlert = true
                } else {
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



struct GroupCardView: View {
    let group: BookGroup

    var body: some View {
        VStack(spacing: 8) {

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




fileprivate struct SectionHeaderView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.leading, 16)
    }
}



fileprivate struct SearchResultRow: View {
    let group: BookGroup
    let currentUserID: String

    @Binding var joinInProgress: Bool
    @Binding var groupToAnswer: BookGroup?
    @Binding var errorMessage: String
    @Binding var showErrorAlert: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
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

