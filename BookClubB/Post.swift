//
//  Post.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//

import Foundation
import FirebaseCore
import FirebaseFirestore

struct Post: Identifiable {
    var id: String

    let author: String

    let authorUID: String?

    let title: String
    let body: String
    let timestamp: Date

    init?(id: String, data: [String: Any]) {
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

        self.authorUID = data["authorUID"] as? String

        self.title = title
        self.body  = body
        self.timestamp = ts.dateValue()
    }
}
