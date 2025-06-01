//
//  GroupDetailViewModel.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class GroupDetailViewModel: ObservableObject {
    @Published var group: BookGroup?
    @Published var isMember: Bool = false
    @Published var hasAnswered: Bool = false

    // Dummy threads for preview:
    let threads: [(username: String, content: String)] = [
        ("Brooke", "The 50th Hunger Games ..."),
        ("Aliya", "Let’s talk about why ...")
    ]

    private var listenerRegistration: ListenerRegistration?

    func bind(to groupID: String) {
        let db = Firestore.firestore()
        listenerRegistration?.remove()

        listenerRegistration = db
            .collection("groups")
            .document(groupID)
            .addSnapshotListener { snapshot, error in
                guard
                    let data = snapshot?.data(),
                    let group = BookGroup.fromDictionary(data, id: groupID),
                    let currentUser = Auth.auth().currentUser
                else {
                    return
                }

                DispatchQueue.main.async {
                    self.group = group
                    self.isMember = group.memberIDs.contains(currentUser.uid)
                    // You can keep hasAnswered logic if you need a separate state
                    self.hasAnswered = self.isMember
                }
            }
    }

    deinit {
        listenerRegistration?.remove()
    }
}
