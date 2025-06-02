//
//  ThreadDetailViewModel.swift
//  BookClubB
//
//  Created by ChatGPT on 6/1/25.
//  Updated 6/1/25 to include an optional authorUID in Reply.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

struct Reply: Identifiable {
    let id: String
    let username: String       // display name
    let authorUID: String?     // ← newly added
    let avatarUrl: String
    let content: String
    let createdAt: Date
}

class ThreadDetailViewModel: ObservableObject {
    @Published var replies: [Reply] = []
    @Published var errorMessage: String?

    private var repliesListener: ListenerRegistration?

    func bind(toGroupID groupID: String, threadID: String) {
        // Remove any existing listener
        repliesListener?.remove()
        replies = []
        errorMessage = nil

        let db = Firestore.firestore()

        // Listen to replies subcollection, ordered by createdAt ascending
        repliesListener = db
            .collection("groups")
            .document(groupID)
            .collection("threads")
            .document(threadID)
            .collection("replies")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to load replies: \(error.localizedDescription)"
                    }
                    return
                }

                guard let docs = snapshot?.documents else {
                    DispatchQueue.main.async {
                        self.replies = []
                    }
                    return
                }

                let fetched: [Reply] = docs.compactMap { doc in
                    let data = doc.data()
                    guard
                        let username  = data["username"]  as? String,
                        let avatarUrl = data["avatarUrl"] as? String,
                        let content   = data["content"]   as? String,
                        let ts        = data["createdAt"] as? Timestamp
                    else {
                        return nil
                    }

                    // authorUID is new; may be missing in older replies
                    let authorUID = data["authorUID"] as? String

                    return Reply(
                        id: doc.documentID,
                        username: username,
                        authorUID: authorUID,
                        avatarUrl: avatarUrl,
                        content: content,
                        createdAt: ts.dateValue()
                    )
                }

                DispatchQueue.main.async {
                    self.replies = fetched
                }
            }
    }

    func detachListeners() {
        repliesListener?.remove()
        repliesListener = nil
    }

    deinit {
        detachListeners()
    }
}
