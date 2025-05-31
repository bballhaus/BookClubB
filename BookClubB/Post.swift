//
//  Post.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//

import Foundation
import FirebaseCore

struct Post: Identifiable {
    // Use the document’s Firestore ID (a string) as our model’s `id`.
    var id: String
    let author: String
    let title: String
    let body: String
    let timestamp: Date

    // Failable initializer from a Firestore document dictionary
    init?(id: String, data: [String: Any]) {
        guard
            let author = data["author"] as? String,
            let title  = data["title"]  as? String,
            let body   = data["body"]   as? String,
            let ts     = data["timestamp"] as? Timestamp
        else {
            return nil
        }
        self.id = id
        self.author = author
        self.title  = title
        self.body   = body
        self.timestamp = ts.dateValue()
    }
}

