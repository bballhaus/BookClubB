//
//  ProfileViewModel.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 6/1/25.
//  Fetches the current user’s profile, their groups, and their posts.
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

    init() {
        fetchUserProfile()
    }

    private func fetchUserProfile() {
        guard let currentUser = Auth.auth().currentUser else {
            self.errorMessage = "No signed‐in user found."
            return
        }

        let userDocRef = db.collection("users").document(currentUser.uid)
        userDocRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to fetch user profile: \(error.localizedDescription)"
                }
                return
            }

            guard
                let data = snapshot?.data(),
                let userProfile = UserProfile.fromDictionary(data, id: currentUser.uid)
            else {
                DispatchQueue.main.async {
                    self.errorMessage = "User profile data is malformed."
                }
                return
            }

            DispatchQueue.main.async {
                self.userProfile = userProfile
            }

            // Once we have the userProfile, fetch their groups & posts:
            self.fetchGroups(from: userProfile.groupIDs)
            self.fetchPosts(for: userProfile.username)
        }
    }

    private func fetchGroups(from groupIDs: [String]) {
        // Clear any existing list:
        DispatchQueue.main.async {
            self.groups.removeAll()
        }

        // If the user belongs to no groups, nothing to do:
        guard !groupIDs.isEmpty else { return }

        // Firestore “in” query can only take up to 10 IDs at once.
        // If more than 10, split them in batches of ≤10.
        let batches = stride(from: 0, to: groupIDs.count, by: 10).map {
            Array(groupIDs[$0..<min($0 + 10, groupIDs.count)])
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

                    guard let documents = snapshot?.documents else { return }

                    let fetched = documents.compactMap { doc -> BookGroup? in
                        return BookGroup.fromDictionary(doc.data(), id: doc.documentID)
                    }

                    DispatchQueue.main.async {
                        self.groups.append(contentsOf: fetched)
                    }
                }
        }
    }

    private func fetchPosts(for username: String) {
        // Listen to “posts” where author == username
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

                guard let documents = snapshot?.documents else {
                    DispatchQueue.main.async {
                        self.posts = []
                    }
                    return
                }

                let fetchedPosts = documents.compactMap { doc -> Post? in
                    return Post(id: doc.documentID, data: doc.data())
                }

                DispatchQueue.main.async {
                    self.posts = fetchedPosts
                }
            }
    }
}
