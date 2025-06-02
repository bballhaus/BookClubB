//
//  GroupDetailViewModel.swift
//  BookClubB
//
// Created by Brooke Ballhaus on 5/31/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class GroupDetailViewModel: ObservableObject {
    @Published var group: BookGroup? = nil

    // Holds the usernames (String) of every moderator UID in group.moderatorIDs
    @Published var moderatorUsernames: [String] = []

    // Holds the list of threads (posts) in this group
    @Published var threads: [GroupThread] = []

    // True if the signed-in user is already a member of this group
    @Published var isMember: Bool = false

    private var groupListener: ListenerRegistration?
    private var threadsListener: ListenerRegistration?

    /// Start listening to Firestore for this group’s document and its threads
    func bind(to groupID: String) {
        let db = Firestore.firestore()
        let groupRef = db.collection("groups").document(groupID)

        // 1) Listen for changes to the group document itself
        groupListener = groupRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("⚠️ Error fetching group: \(error.localizedDescription)")
                return
            }
            guard
                let data = snapshot?.data(),
                let fetchedGroup = BookGroup.fromDictionary(data, id: groupID)
            else {
                return
            }

            DispatchQueue.main.async {
                self.group = fetchedGroup

                // Update membership status
                if let currentUID = Auth.auth().currentUser?.uid {
                    self.isMember = fetchedGroup.memberIDs.contains(currentUID)
                } else {
                    self.isMember = false
                }

                // Fetch the display‐names of all moderator UIDs
                self.fetchModeratorUsernames(modIDs: fetchedGroup.moderatorIDs)
            }
        }

        // 2) Listen for threads (posts) under /groups/{groupID}/threads
        threadsListener = groupRef
            .collection("threads")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("⚠️ Error fetching threads: \(error.localizedDescription)")
                    return
                }
                let docs = snapshot?.documents ?? []
                let fetchedThreads: [GroupThread] = docs.compactMap { doc in
                    GroupThread.fromDictionary(doc.data(), id: doc.documentID)
                }
                DispatchQueue.main.async {
                    self.threads = fetchedThreads
                }
            }
    }

    /// Call in GroupDetailView.onDisappear to stop Firestore listeners
    func detachListeners() {
        groupListener?.remove()
        threadsListener?.remove()
    }

    // ─────────────────────────────────────────────────────────────────────────
    /// Given an array of moderator UIDs, look up each user’s “username” in /users/{modUID},
    /// and store all successfully fetched usernames into `moderatorUsernames`.
    private func fetchModeratorUsernames(modIDs: [String]) {
        guard !modIDs.isEmpty else {
            DispatchQueue.main.async {
                self.moderatorUsernames = []
            }
            return
        }
        let db = Firestore.firestore()
        var names: [String] = []
        let group = DispatchGroup()

        for modUID in modIDs {
            group.enter()
            let userRef = db.collection("users").document(modUID)
            userRef.getDocument { snapshot, error in
                defer { group.leave() }
                if let data = snapshot?.data(),
                   let username = data["username"] as? String {
                    names.append(username)
                }
                // If it fails or “username” is missing, skip that UID.
            }
        }

        group.notify(queue: .main) {
            // Once all lookups finish, update the @Published array
            self.moderatorUsernames = names
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    /// Toggle a “like” on a thread. (Example: use a “likes” subcollection + increment a field.)
    func toggleLike(groupID: String, threadID: String) {
        guard let currentUser = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        let threadRef = db
            .collection("groups")
            .document(groupID)
            .collection("threads")
            .document(threadID)
        let likeDocRef = threadRef
            .collection("likes")
            .document(currentUser.uid)

        likeDocRef.getDocument { snapshot, error in
            if let snapshot = snapshot, snapshot.exists {
                // Already liked → remove like
                let batch = db.batch()
                batch.deleteDocument(likeDocRef)
                batch.updateData([
                    "likesCount": FieldValue.increment(Int64(-1))
                ], forDocument: threadRef)
                batch.commit { batchError in
                    if let batchError = batchError {
                        print("⚠️ Error unliking thread: \(batchError.localizedDescription)")
                    }
                }
            } else {
                // Not yet liked → add like
                let batch = db.batch()
                batch.setData([ "createdAt": Timestamp(date: Date()) ], forDocument: likeDocRef)
                batch.updateData([
                    "likesCount": FieldValue.increment(Int64(1))
                ], forDocument: threadRef)
                batch.commit { batchError in
                    if let batchError = batchError {
                        print("⚠️ Error liking thread: \(batchError.localizedDescription)")
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    /// Delete the thread document at /groups/{groupID}/threads/{threadID}, but only if
    /// the signed‐in user UID exactly equals the group.ownerID. Otherwise print a warning.
    func deleteThread(groupID: String, threadID: String) {
        guard let currentUID = Auth.auth().currentUser?.uid else {
            print("⚠️ deleteThread called but no user is signed in.")
            return
        }
        guard let ownerID = group?.ownerID, currentUID == ownerID else {
            print("⚠️ deleteThread: only owner can delete a post.")
            return
        }

        let db = Firestore.firestore()
        let threadRef = db
            .collection("groups")
            .document(groupID)
            .collection("threads")
            .document(threadID)

        threadRef.delete { error in
            if let error = error {
                print("⚠️ Error deleting thread: \(error.localizedDescription)")
            } else {
                print("✅ Successfully deleted thread \(threadID).")
                // The threadsListener will automatically remove it from `self.threads`
            }
        }
    }
}
