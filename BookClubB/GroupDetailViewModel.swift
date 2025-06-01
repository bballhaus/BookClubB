//
//  GroupDetailViewModel.swift
//  BookClubB
//
//  Created by YourName on 6/1/25.
//  Updated 6/1/25 to support per-user thread likes with a "likes" subcollection.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// ───────────────────────────────────────────────────────────────────────────────
// MARK: – ThreadModel
// A struct representing one “post” (formerly named `Thread`), now including
// a local flag `isLikedByCurrentUser` for whether the signed-in user has liked it.
// ───────────────────────────────────────────────────────────────────────────────

struct ThreadModel: Identifiable {
    let id: String
    let username: String
    let content: String
    let createdAt: Date
    var likesCount: Int
    let repliesCount: Int
    let avatarUrl: String
    
    /// Indicates if the current user has already liked this thread.
    var isLikedByCurrentUser: Bool = false
}

// ───────────────────────────────────────────────────────────────────────────────
// MARK: – GroupDetailViewModel
//
// Listens to a single group document and its “threads” subcollection.
// Publishes:
//  • `group`        – the BookGroup data
//  • `threads`      – a list of ThreadModel instances (real-time)
//  • `isMember`     – whether the current user is already in group.memberIDs
//  • `hasAnswered`  – whether the current user has submitted the moderation answer
// ───────────────────────────────────────────────────────────────────────────────

class GroupDetailViewModel: ObservableObject {
    @Published var group: BookGroup?       = nil
    @Published var threads: [ThreadModel]  = []
    @Published var isMember: Bool          = false
    @Published var hasAnswered: Bool       = false

    private var groupListener: ListenerRegistration?
    private var threadsListener: ListenerRegistration?

    /// Start (or restart) listeners for this group’s document and its threads
    func bind(to groupID: String) {
        // 1) Remove any existing listeners
        groupListener?.remove()
        threadsListener?.remove()

        let db = Firestore.firestore()
        let groupRef = db.collection("groups").document(groupID)

        // ─── Listen to the group document ─────────────────────────────────
        groupListener = groupRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("❌ Error listening to group \(groupID): \(error.localizedDescription)")
                return
            }
            guard let data = snapshot?.data() else {
                print("⚠️ Group \(groupID) data was nil")
                self.group = nil
                return
            }
            if let bookGroup = BookGroup.fromDictionary(data, id: groupID) {
                DispatchQueue.main.async {
                    self.group = bookGroup
                    if let currentUID = Auth.auth().currentUser?.uid {
                        self.isMember = bookGroup.memberIDs.contains(currentUID)
                        self.hasAnswered = false
                    } else {
                        self.isMember = false
                        self.hasAnswered = false
                    }
                }
            } else {
                print("⚠️ Could not parse BookGroup for doc \(groupID)")
                DispatchQueue.main.async {
                    self.group = nil
                }
            }
        }

        // ─── Listen to the “threads” subcollection ────────────────────────────
        threadsListener = groupRef
            .collection("threads")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("❌ Error listening to threads: \(error.localizedDescription)")
                    return
                }
                guard let docs = snapshot?.documents else {
                    DispatchQueue.main.async { self.threads = [] }
                    return
                }

                let currentUID = Auth.auth().currentUser?.uid
                var fetchedThreads: [ThreadModel] = []

                // 1) Create ThreadModel entries without isLikedByCurrentUser
                for doc in docs {
                    let data = doc.data()
                    guard
                        let username  = data["username"]   as? String,
                        let content   = data["content"]    as? String,
                        let timestamp = data["createdAt"]  as? Timestamp,
                        let likes     = data["likesCount"] as? Int,
                        let replies   = data["repliesCount"] as? Int,
                        let avatarUrl = data["avatarUrl"]  as? String
                    else {
                        print("⚠️ Missing fields in thread \(doc.documentID)")
                        continue
                    }

                    var thread = ThreadModel(
                        id: doc.documentID,
                        username: username,
                        content: content,
                        createdAt: timestamp.dateValue(),
                        likesCount: likes,
                        repliesCount: replies,
                        avatarUrl: avatarUrl,
                        isLikedByCurrentUser: false
                    )
                    fetchedThreads.append(thread)
                }

                // 2) For each thread, check if the current user has a “like” doc under it
                let dispatchGroup = DispatchGroup()
                for index in fetchedThreads.indices {
                    guard let uid = currentUID else { continue }
                    dispatchGroup.enter()
                    let likeDocRef = groupRef
                        .collection("threads")
                        .document(fetchedThreads[index].id)
                        .collection("likes")
                        .document(uid)
                    likeDocRef.getDocument { snap, _ in
                        if let snap = snap, snap.exists {
                            fetchedThreads[index].isLikedByCurrentUser = true
                        }
                        dispatchGroup.leave()
                    }
                }

                // 3) Once all checks finish, publish the array
                dispatchGroup.notify(queue: .main) {
                    self.threads = fetchedThreads
                }
            }
    }

    /// Call this when the view disappears (to clean up listeners)
    func detachListeners() {
        groupListener?.remove()
        threadsListener?.remove()
        groupListener = nil
        threadsListener = nil
    }

    /// Toggle like/unlike for the current user on a specific thread
    func toggleLike(groupID: String, threadID: String) {
        guard let currentUID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let threadRef = db
            .collection("groups")
            .document(groupID)
            .collection("threads")
            .document(threadID)
        let likeDocRef = threadRef
            .collection("likes")
            .document(currentUID)

        likeDocRef.getDocument { snapshot, error in
            if let snapshot = snapshot, snapshot.exists {
                // Already liked → Unlike
                let batch = db.batch()
                batch.deleteDocument(likeDocRef)
                batch.updateData(["likesCount": FieldValue.increment(Int64(-1))], forDocument: threadRef)
                batch.commit { batchError in
                    if let batchError = batchError {
                        print("Error unliking thread: \(batchError.localizedDescription)")
                    }
                }
            } else {
                // Not yet liked → Like
                let batch = db.batch()
                batch.setData([ "createdAt": Timestamp(date: Date()) ], forDocument: likeDocRef)
                batch.updateData(["likesCount": FieldValue.increment(Int64(1))], forDocument: threadRef)
                batch.commit { batchError in
                    if let batchError = batchError {
                        print("Error liking thread: \(batchError.localizedDescription)")
                    }
                }
            }
        }
    }

    deinit {
        detachListeners()
    }
}
