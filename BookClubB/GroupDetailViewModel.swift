//
//  GroupDetailViewModel.swift
//  BookClubB
//
//  Created by YourName on 6/1/25.
//  Updated 6/4/25: correct thread parsing & fetch ownerUsername.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class GroupDetailViewModel: ObservableObject {
    @Published var group: BookGroup? = nil
    @Published var ownerUsername: String = ""
    @Published var threads: [GroupThread] = []
    @Published var isMember: Bool = false
    
    private var groupListener: ListenerRegistration?
    private var threadsListener: ListenerRegistration?

    /// Call this in GroupDetailView.onAppear(groupID:) to start listening
    func bind(to groupID: String) {
        let db = Firestore.firestore()
        let groupRef = db.collection("groups").document(groupID)

        // 1) Listen to the group document itself
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

                // Fetch the owner’s username from /users/{ownerID}
                self.fetchOwnerUsername(ownerID: fetchedGroup.ownerID)
            }
        }

        // 2) Listen to “groups/{groupID}/threads” subcollection, sorted by createdAt descending
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

    /// Detach Firestore listeners (call in onDisappear)
    func detachListeners() {
        groupListener?.remove()
        threadsListener?.remove()
    }

    /// Look up the ownerUsername from Firestore “users/{ownerID}” document
    private func fetchOwnerUsername(ownerID: String) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(ownerID)
        userRef.getDocument { snapshot, error in
            if let data = snapshot?.data(),
               let username = data["username"] as? String {
                DispatchQueue.main.async {
                    self.ownerUsername = username
                }
            } else {
                DispatchQueue.main.async {
                    self.ownerUsername = ""
                }
            }
        }
    }

    /// Toggle like/unlike for a given thread. Adjust to match your Firestore schema.
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
}
