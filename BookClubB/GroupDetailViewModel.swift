// GroupDetailViewModel.swift

import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Only define Thread once, here in the ViewModel file.
struct Thread: Identifiable {
    let id: String
    let username: String
    let content: String
    let createdAt: Date
    let likesCount: Int
    let repliesCount: Int
    let avatarUrl: String
}

class GroupDetailViewModel: ObservableObject {
    @Published var group: BookGroup?
    @Published var isMember: Bool = false
    @Published var hasAnswered: Bool = false

    @Published var threads: [Thread] = []

    private var groupListener: ListenerRegistration?
    private var threadsListener: ListenerRegistration?

    func bind(to groupID: String) {
        let db = Firestore.firestore()
        groupListener?.remove()
        threadsListener?.remove()

        // 1) Listen for changes to the group document
        groupListener = db
            .collection("groups")
            .document(groupID)
            .addSnapshotListener { snapshot, error in
                guard
                    let data = snapshot?.data(),
                    let fetchedGroup = BookGroup.fromDictionary(data, id: groupID),
                    let currentUser = Auth.auth().currentUser
                else { return }

                DispatchQueue.main.async {
                    self.group = fetchedGroup
                    self.isMember = fetchedGroup.memberIDs.contains(currentUser.uid)
                    self.hasAnswered = self.isMember
                }
            }

        // 2) Listen for threads under /groups/{groupID}/threads, newest first
        threadsListener = db
            .collection("groups")
            .document(groupID)
            .collection("threads")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let docs = snapshot?.documents else { return }

                let fetchedThreads: [Thread] = docs.compactMap { doc in
                    let data = doc.data()
                    guard
                        let username   = data["username"]   as? String,
                        let content    = data["content"]    as? String,
                        let timestamp  = data["createdAt"]  as? Timestamp,
                        let likes      = data["likesCount"] as? Int,
                        let replies    = data["repliesCount"] as? Int,
                        let avatarUrl  = data["avatarUrl"]  as? String
                    else {
                        return nil
                    }
                    return Thread(
                        id: doc.documentID,
                        username: username,
                        content: content,
                        createdAt: timestamp.dateValue(),
                        likesCount: likes,
                        repliesCount: replies,
                        avatarUrl: avatarUrl
                    )
                }

                DispatchQueue.main.async {
                    self.threads = fetchedThreads
                }
            }
    }

    deinit {
        groupListener?.remove()
        threadsListener?.remove()
    }
}
