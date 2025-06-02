//
//  ProfileViewModel.swift
//  BookClubB
//
//  Created by ChatGPT on 6/1/25.
//  Updated 6/11/25 so that the initializer’s label is `username:` (not `viewingUsername:`).
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class ProfileViewModel: ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var groups: [BookGroup] = []
    @Published var posts: [Post] = []
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()

    /// If `username` is nil, show the signed‐in user’s profile.
    /// Otherwise, show that user’s profile by querying `/users` where "username" == this string.
    private let usernameToLookup: String?

    /// **IMPORTANT**: the parameter label here must be `username:` so it matches how ProfileView calls it.
    init(username: String? = nil) {
        self.usernameToLookup = username
        fetchUserProfile()
    }

    private func fetchUserProfile() {
        // Decide which username to actually query:
        let lookup: String
        if let explicit = usernameToLookup {
            lookup = explicit
        } else if let currentUsername = Auth.auth().currentUser?.displayName {
            lookup = currentUsername
        } else {
            DispatchQueue.main.async {
                self.errorMessage = "No signed-in user found."
            }
            return
        }

        // Now look up `/users` where `username == lookup`
        db.collection("users")
            .whereField("username", isEqualTo: lookup)
            .limit(to: 1)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to fetch profile: \(error.localizedDescription)"
                    }
                    return
                }

                guard
                    let document = snapshot?.documents.first,
                    let profile = UserProfile.fromDictionary(document.data(), id: document.documentID)
                else {
                    DispatchQueue.main.async {
                        self.errorMessage = "User '\(lookup)' not found or data malformed."
                    }
                    return
                }

                DispatchQueue.main.async {
                    self.userProfile = profile
                }

                // Fetch that user’s groups and posts
                self.fetchGroups(from: profile.groupIDs)
                self.fetchPosts(forUsername: lookup)
            }
    }

    /// Fetch BookGroup documents whose IDs are in `groupIDs`
    private func fetchGroups(from groupIDs: [String]) {
        DispatchQueue.main.async { self.groups.removeAll() }
        guard !groupIDs.isEmpty else { return }

        // Split into batches of ≤10 for Firestore “in” query
        let batches = stride(from: 0, to: groupIDs.count, by: 10).map {
            Array(groupIDs[$0 ..< min($0 + 10, groupIDs.count)])
        }

        for batch in batches {
            db.collection("groups")
                .whereField(FieldPath.documentID(), in: batch)
                .getDocuments { [weak self] snapshot, error in
                    guard let self = self else { return }
                    if let error = error {
                        DispatchQueue.main.async {
                            self.errorMessage = "Failed to fetch groups: \(error.localizedDescription)"
                        }
                        return
                    }
                    guard let docs = snapshot?.documents else { return }
                    let fetched = docs.compactMap { doc -> BookGroup? in
                        BookGroup.fromDictionary(doc.data(), id: doc.documentID)
                    }
                    DispatchQueue.main.async {
                        self.groups.append(contentsOf: fetched)
                    }
                }
        }
    }

    /// Fetch all posts where `author == username`
    private func fetchPosts(forUsername username: String) {
        db.collection("posts")
            .whereField("author", isEqualTo: username)
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = "Error fetching posts: \(error.localizedDescription)"
                    }
                    return
                }
                guard let docs = snapshot?.documents else {
                    DispatchQueue.main.async {
                        self.posts = []
                    }
                    return
                }
                let fetched = docs.compactMap { doc -> Post? in
                    return Post(id: doc.documentID, data: doc.data())
                }
                DispatchQueue.main.async {
                    self.posts = fetched
                }
            }
    }
}
