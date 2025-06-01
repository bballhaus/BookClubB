//
//  Comment.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//

import Foundation
import FirebaseFirestore

struct Comment: Identifiable {
    var id: String            // Firestore document ID under groups/{groupID}/threads/{threadID}/comments
    let authorID: String
    let content: String
    let timestamp: Date

    static func fromDictionary(_ dict: [String: Any], id: String) -> Comment? {
        guard
            let authorID = dict["authorID"] as? String,
            let content = dict["content"] as? String,
            let ts = dict["timestamp"] as? Timestamp
        else {
            return nil
        }
        return Comment(
            id: id,
            authorID: authorID,
            content: content,
            timestamp: ts.dateValue()
        )
    }

    func toDictionary() -> [String: Any] {
        return [
            "authorID": authorID,
            "content": content,
            "timestamp": Timestamp(date: timestamp)
        ]
    }
}
