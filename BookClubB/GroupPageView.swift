//
//  GroupPageView.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//  Updated to add tappable NavigationLinks so that tapping a group pushes into GroupDetailView.
//  This file contains GroupPageView and all of its helper subviews (including DefaultGroupsView, SearchResultsView, etc.).
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct GroupPageView: View {
    // ── 1) State variables ──────────────────────────────────────────────
    @State private var allGroups: [BookGroup] = []   // All groups fetched from Firestore
    @State private var isLoading: Bool = false       // Show spinner while fetching
    @State private var errorMessage: String? = nil   // Any fetch errors
    
    // This holds whatever the user types into the search bar
    @State private var searchText: String = ""
    
    // Computed property for the current user’s UID
    private var currentUserID: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    // Optional dropdown suggestions for the search bar
    private var searchSuggestions: [String] {
        let lower = searchText.lowercased()
        return allGroups
            .map { $0.title }
            .filter { $0.lowercased().contains(lower) }
            .prefix(5)
            .map { $0 }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // 1) Show a spinner while loading
                if isLoading {
                    ProgressView("Loading groups…")
                        .padding()
                }
                // 2) Show any fetch error
                else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                // 3) If the user has typed something into the search bar, show filtered results
                else if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    SearchResultsView(
                        searchText: searchText,
                        allGroups: allGroups,
                        onJoinComplete: fetchAllGroups
                    )
                }
                // 4) Otherwise, show the “New Group / Your Groups / Groups You Might Be Interested In” UI
                else {
                    DefaultGroupsView(
                        allGroups: allGroups,
                        onJoinComplete: fetchAllGroups
                    )
                }
            }
            .navigationTitle("Groups")
            // Force a large title so the search bar appears directly below it
            .navigationBarTitleDisplayMode(.large)
            // Attach the native iOS search bar right under “Groups”
            .searchable(
                text: $searchText,
                prompt: "Search all groups"
            ) {
                // (Optional) live dropdown suggestions
                ForEach(searchSuggestions, id: \.self) { suggestion in
                    Text(suggestion)
                        .searchCompletion(suggestion)
                }
            }
            .onAppear(perform: fetchAllGroups)
        }
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
                
                // Parse each document into BookGroup
                self.allGroups = docs.compactMap { doc in
                    BookGroup.fromDictionary(doc.data(), id: doc.documentID)
                }
            }
        }
    }
}

// ───────────────────────────────────────────────────────────────────────
// MARK: – DefaultGroupsView
// (Displays “New Group” card, “Your Groups” horizontal scroller, and
//  “Groups You Might Be Interested In” horizontal scroller. Tappable covers.)
// ───────────────────────────────────────────────────────────────────────

fileprivate struct DefaultGroupsView: View {
    let allGroups: [BookGroup]
    let onJoinComplete: () -> Void
    
    // Required to determine which groups are “Your Groups” vs. “Other Groups”
    private var currentUserID: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    // Holds state for join button feedback
    @State private var joinInProgress: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var joinErrorMessage: String = ""
    
    // “Your Groups” = user is already in memberIDs
    private var yourGroups: [BookGroup] {
        allGroups.filter { $0.memberIDs.contains(currentUserID) }
    }
    
    // “Other Groups” = user is not yet a member
    private var otherGroups: [BookGroup] {
        allGroups.filter { !$0.memberIDs.contains(currentUserID) }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // ─── “New Group” Banner ────────────────────────────
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
                
                // ─── “Your Groups” Section (each card is tappable) ─────
                if !yourGroups.isEmpty {
                    SectionHeaderView(title: "Your Groups")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(yourGroups) { group in
                                NavigationLink(
                                    destination: GroupDetailView(groupID: group.id)
                                ) {
                                    GroupCardView(group: group)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // ─── “Groups You Might Be Interested In” (cover + separate Join) ─
                if !otherGroups.isEmpty {
                    SectionHeaderView(title: "Groups You Might Be Interested In")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(otherGroups) { group in
                                VStack(spacing: 8) {
                                    // 1) Tappable cover and title → navigates to detail
                                    NavigationLink(
                                        destination: GroupDetailView(groupID: group.id)
                                    ) {
                                        VStack {
                                            AsyncImage(url: URL(string: group.imageUrl)) { phase in
                                                switch phase {
                                                case .empty:
                                                    ProgressView()
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
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    // 2) Join button below the cover (only if not already a member)
                                    if group.memberIDs.contains(currentUserID) {
                                        Text("Joined")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                    } else {
                                        Button(action: {
                                            joinGroup(group)
                                        }) {
                                            if joinInProgress {
                                                ProgressView()
                                                    .scaleEffect(0.8, anchor: .center)
                                            } else {
                                                Text("Join")
                                                    .font(.caption2)
                                                    .padding(.vertical, 4)
                                                    .padding(.horizontal, 8)
                                                    .background(Color.blue.opacity(0.2))
                                                    .cornerRadius(6)
                                            }
                                        }
                                        .disabled(joinInProgress)
                                        .alert(isPresented: $showErrorAlert) {
                                            Alert(
                                                title: Text("Could not join"),
                                                message: Text(joinErrorMessage),
                                                dismissButton: .default(Text("OK"))
                                            )
                                        }
                                    }
                                }
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
    
    // MARK: – Helper to join a group
    private func joinGroup(_ group: BookGroup) {
        guard let user = Auth.auth().currentUser else {
            joinErrorMessage = "You must be signed in to join."
            showErrorAlert = true
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
                joinErrorMessage = err.localizedDescription
                showErrorAlert = true
            } else {
                onJoinComplete()
            }
        }
    }
}

// ───────────────────────────────────────────────────────────────────────
// MARK: – SearchResultsView
// (Displays a vertical list of all groups whose title contains `searchText`)
// ───────────────────────────────────────────────────────────────────────

fileprivate struct SearchResultsView: View {
    let searchText: String
    let allGroups: [BookGroup]
    let onJoinComplete: () -> Void
    
    // Computed property for the current user’s UID
    private var currentUserID: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    // Filtered list of groups whose titles match the search text
    private var matchingGroups: [BookGroup] {
        let lower = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allGroups.filter { $0.title.lowercased().contains(lower) }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            if matchingGroups.isEmpty {
                Text("No groups found for “\(searchText)”")
                    .foregroundColor(.gray)
                    .italic()
                    .padding()
            } else {
                List {
                    ForEach(matchingGroups) { group in
                        HStack {
                            Text(group.title)
                                .font(.body)
                            Spacer()
                            
                            // If the user is already a member, show a checkmark
                            if group.memberIDs.contains(currentUserID) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                            }
                            // Otherwise show a “Join” button inline
                            else {
                                Button("Join") {
                                    joinGroup(group)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
    
    private func joinGroup(_ group: BookGroup) {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        let groupRef = db.collection("groups").document(group.id)
        
        groupRef.updateData([
            "memberIDs": FieldValue.arrayUnion([user.uid]),
            "updatedAt": Timestamp(date: Date())
        ]) { err in
            if let err = err {
                print("Could not join: \(err.localizedDescription)")
            } else {
                onJoinComplete()
            }
        }
    }
}

// ───────────────────────────────────────────────────────────────────────
// MARK: – SectionHeaderView
// A simple header for each horizontal section (Your Groups, Other Groups)
// ───────────────────────────────────────────────────────────────────────

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

// ───────────────────────────────────────────────────────────────────────
// MARK: – GroupCardView
// Shows a large cover image + title for “Your Groups”
// ───────────────────────────────────────────────────────────────────────

fileprivate struct GroupCardView: View {
    let group: BookGroup
    
    var body: some View {
        VStack(spacing: 8) {
            AsyncImage(url: URL(string: group.imageUrl)) { phase in
                switch phase {
                case .empty:
                    // Placeholder rectangle while loading
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 140, height: 200)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 200)
                        .cornerRadius(8)
                case .failure:
                    // Fallback if the URL is bad
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.1))
                        .overlay(
                            Image(systemName: "xmark.octagon.fill")
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
