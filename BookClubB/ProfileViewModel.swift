//
//  ProfileViewModel.swift
//  BookClubB
//
//  Created by ChatGPT on 6/1/25.
//  Updated 6/12/25 to fetch the user’s groups (title & image) and posts.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class ProfileViewModel: ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var userGroups: [BookGroup] = []
    @Published var userPosts: [Post] = []
    @Published var errorMessage: String?
    @Published var showingEditSheet = false

    /// True when we’re looking at our own profile
    @Published var isViewingOwnProfile = false

    private let db = Firestore.firestore()
    private let viewingUsername: String?

    /// If `username` is nil, fetch current user’s profile by UID;
    /// otherwise lookup by that handle.
    init(username: String? = nil) {
        self.viewingUsername = username
        fetchUserProfile()
    }

    /// 1) Load the UserProfile (which gives us `profile.id` (UID) and `profile.groupIDs`)
    /// 2) Once we have `userProfile`, call `fetchUserGroups()` and `fetchUserPosts()`
    private func fetchUserProfile() {
        if let lookupHandle = viewingUsername {
            // ── LOOKUP ANOTHER USER BY THEIR HANDLE (“username”) ──
            db.collection("users")
                .whereField("username", isEqualTo: lookupHandle)
                .limit(to: 1)
                .getDocuments { [weak self] snapshot, error in
                    guard let self = self else { return }
                    if let error = error {
                        DispatchQueue.main.async {
                            self.errorMessage = "Failed to fetch profile: \(error.localizedDescription)"
                        }
                        return
                    }
                    if let doc = snapshot?.documents.first,
                       let profile = UserProfile.fromDictionary(doc.data(), id: doc.documentID) {
                        DispatchQueue.main.async {
                            self.userProfile = profile
                            self.setIsViewingOwnProfile()
                            self.fetchUserGroups()
                            self.fetchUserPosts()
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.errorMessage = "User “\(lookupHandle)” not found."
                        }
                    }
                }
        } else {
            // ── FETCH CURRENT USER’S PROFILE BY UID ──
            guard let currentUID = Auth.auth().currentUser?.uid else {
                DispatchQueue.main.async {
                    self.errorMessage = "Not signed in."
                }
                return
            }

            let ref = db.collection("users").document(currentUID)
            ref.getDocument { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to fetch my profile: \(error.localizedDescription)"
                    }
                    return
                }
                if let data = snapshot?.data(),
                   let profile = UserProfile.fromDictionary(data, id: currentUID) {
                    DispatchQueue.main.async {
                        self.userProfile = profile
                        self.setIsViewingOwnProfile()
                        self.fetchUserGroups()
                        self.fetchUserPosts()
                    }
                } else {
                    DispatchQueue.main.async {
                        self.errorMessage = "My user document not found or data malformed."
                    }
                }
            }
        }
    }

    /// Compare loaded profile’s UID to current auth UID
    private func setIsViewingOwnProfile() {
        if let profile = userProfile,
           let currentUID = Auth.auth().currentUser?.uid {
            isViewingOwnProfile = (profile.id == currentUID)
        } else {
            isViewingOwnProfile = false
        }
    }

    // MARK: – Fetch the user’s Group objects (title + imageUrl) from groupIDs
    private func fetchUserGroups() {
        guard let profile = userProfile else { return }

        // Reset in case this method is called again
        userGroups = []

        let groupIDs = profile.groupIDs
        // If no groupIDs, leave userGroups empty
        guard !groupIDs.isEmpty else { return }

        let groupCollection = db.collection("groups")
        let dispatchGroup = DispatchGroup()
        var fetchedGroups: [BookGroup] = []

        for gid in groupIDs {
            dispatchGroup.enter()
            groupCollection.document(gid).getDocument { snapshot, error in
                defer { dispatchGroup.leave() }
                if let data = snapshot?.data(),
                   let group = BookGroup.fromDictionary(data, id: gid) {
                    fetchedGroups.append(group)
                }
                // If missing or malformed, just skip that ID
            }
        }

        dispatchGroup.notify(queue: .main) {
            // Sort however you like (e.g., by title). Here we preserve Firestore order:
            self.userGroups = fetchedGroups
        }
    }

    // MARK: – Fetch the user’s own posts (filter “posts” where authorUID == profile.id)
    private func fetchUserPosts() {
        guard let profile = userProfile else { return }

        db.collection("posts")
            .whereField("authorUID", isEqualTo: profile.id)
            .order(by: "timestamp", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to fetch user’s posts: \(error.localizedDescription)"
                        self.userPosts = []
                    }
                    return
                }
                let docs = snapshot?.documents ?? []
                let fetched: [Post] = docs.compactMap { doc in
                    return Post(id: doc.documentID, data: doc.data())
                }
                DispatchQueue.main.async {
                    self.userPosts = fetched
                }
            }
    }

    // MARK: – Edit Display Name (unchanged from before)

    func updateDisplayName(to newDisplayName: String) {
        guard let currentUser = Auth.auth().currentUser else { return }
        let currentUID = currentUser.uid

        // 1) Update Auth.displayName
        let changeRequest = currentUser.createProfileChangeRequest()
        changeRequest.displayName = newDisplayName
        changeRequest.commitChanges { [weak self] error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.errorMessage = "Failed to update Auth displayName: \(error.localizedDescription)"
                }
                return
            }
            // 2) Update Firestore “displayName”
            self?.db.collection("users").document(currentUID).updateData([
                "displayName": newDisplayName
            ]) { [weak self] err in
                if let err = err {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Failed to update Firestore displayName: \(err.localizedDescription)"
                    }
                    return
                }
                // 3) Immediately update local model so UI refreshes
                DispatchQueue.main.async {
                    self?.userProfile?.displayName = newDisplayName
                }
            }
        }
    }

    // MARK: – Upload Profile Image (unchanged from before)
    func uploadProfileImage(_ image: UIImage) {
        // ... existing code for uploading to Storage, updating Firestore, etc. :contentReference[oaicite:0]{index=0}
    }
}
