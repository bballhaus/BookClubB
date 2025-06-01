//
//  GroupPageView.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//  Revised so that the search bar always appears.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct GroupPageView: View {
    @State private var allGroups: [BookGroup] = []   // All groups fetched from Firestore
    @State private var isLoading: Bool = false       // Show spinner while fetching
    @State private var errorMessage: String? = nil   // Any fetch errors

    @State private var searchText: String = ""       // What the user types into the search bar

    var body: some View {
        NavigationView {
            VStack {
                // 1) Show a spinner while loading:
                if isLoading {
                    ProgressView("Loading groups...")
                        .padding()
                }

                // 2) Show any error if it occurred:
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }

                // 3) If the user has typed something, show the search results:
                if !searchText.isEmpty {
                    SearchResultsView(
                        searchText: searchText,
                        allGroups: allGroups,
                        onJoinComplete: fetchAllGroups
                    )
                }
                // 4) Otherwise, show the default two-row UI:
                else {
                    DefaultGroupsView(
                        allGroups: allGroups,
                        onJoinComplete: fetchAllGroups
                    )
                }
            }
            .navigationTitle("Groups")
            // Attach the search bar here, at the top of the NavigationView
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Search all groups"
            ) {
                // Optional: offer title-based suggestions as the user types
                ForEach(searchSuggestions, id: \.self) { suggestion in
                    Text(suggestion)
                        .searchCompletion(suggestion)
                }
            }
            .onAppear(perform: fetchAllGroups)
        }
    }

    // MARK: – Computed Properties

    /// The current user’s UID
    private var currentUserID: String {
        Auth.auth().currentUser?.uid ?? ""
    }

    /// All group titles that contain `searchText` (for suggestion dropdown)
    private var searchSuggestions: [String] {
        let lowered = searchText.lowercased()
        return allGroups
            .map { $0.title }
            .filter { $0.lowercased().contains(lowered) }
    }

    // MARK: – Firestore Fetch

    /// Load every document in `/groups` into `allGroups`
    private func fetchAllGroups() {
        guard Auth.auth().currentUser != nil else {
            self.errorMessage = "You must be signed in to view groups."
            return
        }

        isLoading = true
        errorMessage = nil

        let db = Firestore.firestore()
        db.collection("groups").getDocuments { snapshot, error in
            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    self.errorMessage = "Failed to load groups: \(error.localizedDescription)"
                    return
                }

                guard let docs = snapshot?.documents else {
                    self.allGroups = []
                    return
                }

                // Parse each document into a BookGroup
                self.allGroups = docs.compactMap { doc in
                    BookGroup.fromDictionary(doc.data(), id: doc.documentID)
                }
            }
        }
    }
}


/// Shows “New Group” + “Your Groups” + “Groups You Might Be Interested In”
fileprivate struct DefaultGroupsView: View {
    let allGroups: [BookGroup]
    let onJoinComplete: () -> Void

    private var currentUserID: String {
        Auth.auth().currentUser?.uid ?? ""
    }

    private var yourGroups: [BookGroup] {
        allGroups.filter { $0.memberIDs.contains(currentUserID) }
    }

    private var otherGroups: [BookGroup] {
        allGroups.filter { !$0.memberIDs.contains(currentUserID) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // ─── “New Group” Banner ───
                NavigationLink(destination: CreateGroupView()) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(white: 0.95))
                            .frame(height: 120)

                        HStack(spacing: 16) {
                            Text("New Group")
                                .font(.title2)
                                .bold()
                                .padding(.leading)

                            Spacer()

                            Image(systemName: "plus.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                                .padding(.trailing)
                        }
                    }
                    .padding(.horizontal)
                }

                // ─── “Your Groups” Section ───
                if !yourGroups.isEmpty {
                    SectionHeaderView(title: "Your Groups")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(yourGroups) { group in
                                GroupCardView(group: group)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // ─── “Groups You Might Be Interested In” Section ───
                if !otherGroups.isEmpty {
                    SectionHeaderView(title: "Groups You Might Be Interested In")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(otherGroups) { group in
                                InterestGroupCircleView(
                                    group: group,
                                    onJoinComplete: onJoinComplete
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(.top)
        }
    }
}


/// Shows a vertical list of all groups whose title contains `searchText`
fileprivate struct SearchResultsView: View {
    let searchText: String
    let allGroups: [BookGroup]
    let onJoinComplete: () -> Void

    private var currentUserID: String {
        Auth.auth().currentUser?.uid ?? ""
    }

    private var matchingGroups: [BookGroup] {
        let lowerSearch = searchText.lowercased()
        return allGroups.filter { group in
            group.title.lowercased().contains(lowerSearch)
        }
    }

    var body: some View {
        if matchingGroups.isEmpty {
            VStack {
                Spacer()
                Text("No groups found matching “\(searchText)”")
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(matchingGroups) { group in
                        HStack(spacing: 16) {
                            AsyncImage(url: URL(string: group.imageUrl)) { phase in
                                switch phase {
                                case .empty:
                                    Circle()
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(width: 60, height: 60)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(Circle())
                                        .shadow(radius: 2)
                                case .failure:
                                    Circle()
                                        .fill(Color.red.opacity(0.1))
                                        .overlay(
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.red)
                                        )
                                        .frame(width: 60, height: 60)
                                @unknown default:
                                    Circle()
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(width: 60, height: 60)
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.title)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text("\(group.memberIDs.count) member(s)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if group.memberIDs.contains(currentUserID) {
                                // If already a member, show a “>” to navigate to detail
                                NavigationLink(destination: GroupDetailView(groupID: group.id)) {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                            } else {
                                // Otherwise, show a Join button
                                JoinButtonInline(
                                    group: group,
                                    onJoinComplete: onJoinComplete
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
    }
}


/// A tappable circle + “Join” button for the “Suggested” row
fileprivate struct InterestGroupCircleView: View {
    let group: BookGroup
    let onJoinComplete: () -> Void

    @State private var joinInProgress: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showErrorAlert: Bool = false

    private var currentUserID: String {
        Auth.auth().currentUser?.uid ?? ""
    }

    var body: some View {
        VStack(spacing: 8) {
            AsyncImage(url: URL(string: group.imageUrl)) { phase in
                switch phase {
                case .empty:
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 80, height: 80)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .shadow(radius: 2)
                case .failure:
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .overlay(
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                        )
                        .frame(width: 80, height: 80)
                @unknown default:
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 80, height: 80)
                }
            }

            Text(group.title)
                .font(.caption)
                .multilineTextAlignment(.center)
                .frame(width: 80)

            Button(action: joinGroup) {
                if joinInProgress {
                    ProgressView()
                        .scaleEffect(0.8, anchor: .center)
                        .padding(.vertical, 4)
                        .frame(width: 80)
                } else {
                    Text("Join")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(width: 80, height: 28)
                        .background(Color.blue)
                        .cornerRadius(14)
                }
            }
            .disabled(joinInProgress)
            .alert(isPresented: $showErrorAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage ?? "Unknown"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func joinGroup() {
        guard let currentUser = Auth.auth().currentUser else { return }
        joinInProgress = true

        let db = Firestore.firestore()
        let docRef = db.collection("groups").document(group.id)

        docRef.updateData([
            "memberIDs": FieldValue.arrayUnion([currentUser.uid])
        ]) { err in
            DispatchQueue.main.async {
                self.joinInProgress = false
                if let err = err {
                    self.errorMessage = "Could not join: \(err.localizedDescription)"
                    self.showErrorAlert = true
                } else {
                    // Firestore write succeeded → reload allGroups in the parent
                    onJoinComplete()
                }
            }
        }
    }
}


/// Inline “Join” button for search results when you’re not a member
fileprivate struct JoinButtonInline: View {
    let group: BookGroup
    let onJoinComplete: () -> Void

    @State private var isJoining: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showError: Bool = false

    private var currentUserID: String {
        Auth.auth().currentUser?.uid ?? ""
    }

    var body: some View {
        Button(action: joinGroup) {
            if isJoining {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 60, height: 30)
            } else {
                Text("Join")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(width: 60, height: 30)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .disabled(isJoining)
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage ?? "Unknown"),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func joinGroup() {
        guard let currentUser = Auth.auth().currentUser else { return }
        isJoining = true

        let db = Firestore.firestore()
        let docRef = db.collection("groups").document(group.id)

        docRef.updateData([
            "memberIDs": FieldValue.arrayUnion([currentUser.uid])
        ]) { err in
            DispatchQueue.main.async {
                self.isJoining = false
                if let err = err {
                    self.errorMessage = "Could not join: \(err.localizedDescription)"
                    self.showError = true
                } else {
                    // Firestore write succeeded → reload allGroups in the parent
                    onJoinComplete()
                }
            }
        }
    }
}


/// A rectangular card view for “Your Groups”
fileprivate struct GroupCardView: View {
    let group: BookGroup

    var body: some View {
        NavigationLink(destination: GroupDetailView(groupID: group.id)) {
            VStack(alignment: .leading, spacing: 8) {
                AsyncImage(url: URL(string: group.imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        Color.gray.opacity(0.1)
                            .frame(width: 150, height: 220)
                            .cornerRadius(12)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 150, height: 220)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                    case .failure:
                        Color.red.opacity(0.1)
                            .overlay(
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.red)
                                    .font(.title)
                            )
                            .frame(width: 150, height: 220)
                            .cornerRadius(12)
                    @unknown default:
                        Color.gray.opacity(0.1)
                            .frame(width: 150, height: 220)
                            .cornerRadius(12)
                    }
                }

                Text(group.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .frame(width: 150, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}


/// A simple header row with a title and a “>” arrow
fileprivate struct SectionHeaderView: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .padding(.leading)
            Spacer()
            Image(systemName: "chevron.right")
                .padding(.trailing)
        }
    }
}
