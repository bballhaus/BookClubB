//
//  Post.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//  Updated 6/1/25 to include authorUID.
//

import Foundation
import FirebaseCore
import FirebaseFirestore

struct Post: Identifiable {
    // Use the document’s Firestore ID (a string) as our model’s `id`.
    var id: String

    // The display name of the author, e.g. “brooke”
    let author: String

    // The author’s UID (so we can tap “by <author>” and open their profile)
    let authorUID: String?

    let title: String
    let body: String
    let timestamp: Date

    // Failable initializer from a Firestore document dictionary
    init?(id: String, data: [String: Any]) {
        // “author” must always exist
        guard
            let author = data["author"]    as? String,
            let title  = data["title"]     as? String,
            let body   = data["body"]      as? String,
            let ts     = data["timestamp"] as? Timestamp
        else {
            return nil
        }

        self.id = id
        self.author = author

        // authorUID is new; may be missing if older posts exist
        self.authorUID = data["authorUID"] as? String

        self.title = title
        self.body  = body
        self.timestamp = ts.dateValue()
    }
}
