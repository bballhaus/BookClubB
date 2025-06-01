//
//  GroupThread.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//

import Foundation
import FirebaseFirestore

struct GroupThread: Identifiable {
    var id: String               // Firestore document ID under groups/{groupID}/threads
    let authorID: String         // user who posted
    let content: String
    let timestamp: Date
    let likeCount: Int
    let replyCount: Int
    let updatedAt: Date?

    static func fromDictionary(_ dict: [String: Any], id: String) -> GroupThread? {
        guard
            let authorID = dict["authorID"] as? String,
            let content = dict["content"] as? String,
            let ts = dict["timestamp"] as? Timestamp,
            let likeCount = dict["likeCount"] as? Int,
            let replyCount = dict["replyCount"] as? Int
        else {
            return nil
        }
        let updatedTS = dict["updatedAt"] as? Timestamp
        return GroupThread(
            id: id,
            authorID: authorID,
            content: content,
            timestamp: ts.dateValue(),
            likeCount: likeCount,
            replyCount: replyCount,
            updatedAt: updatedTS?.dateValue()
        )
    }

    func toDictionary() -> [String: Any] {
        var data: [String: Any] = [
            "authorID": authorID,
            "content": content,
            "timestamp": Timestamp(date: timestamp),
            "likeCount": likeCount,
            "replyCount": replyCount
        ]
        if let updated = updatedAt {
            data["updatedAt"] = Timestamp(date: updated)
        }
        return data
    }
}
