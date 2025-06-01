//
//  GroupThread.swift
//  BookClubB
//
//  Created by YourName on 6/1/25.
//  Updated 6/4/25 to match Firestore fields “username” / “createdAt” / “likesCount” / “repliesCount”.
//

import Foundation
import FirebaseFirestore

struct GroupThread: Identifiable {
    var id: String
    let authorID: String      // from Firestore field “username”
    let content: String       // from Firestore field “content”
    let timestamp: Date       // from Firestore field “createdAt”
    let likeCount: Int        // from Firestore field “likesCount”
    let replyCount: Int       // from Firestore field “repliesCount”
    let updatedAt: Date?      // optional Firestore field “updatedAt”

    /// Parse a Firestore document into GroupThread.
    /// Expects keys exactly: “username”, “content”, “createdAt”, “likesCount”, “repliesCount”, optional “updatedAt”.
    static func fromDictionary(_ dict: [String: Any], id: String) -> GroupThread? {
        guard
            let authorID   = dict["username"]     as? String,
            let content    = dict["content"]      as? String,
            let ts         = dict["createdAt"]    as? Timestamp,
            let likeCount  = dict["likesCount"]   as? Int,
            let replyCount = dict["repliesCount"] as? Int
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

    /// Convert this GroupThread back into a Firestore dictionary.
    /// (Used if you ever need to write or update a thread document.)
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "username":    authorID,
            "content":     content,
            "createdAt":   Timestamp(date: timestamp),
            "likesCount":  likeCount,
            "repliesCount": replyCount
        ]
        if let updatedAt = updatedAt {
            dict["updatedAt"] = Timestamp(date: updatedAt)
        }
        return dict
    }
}
