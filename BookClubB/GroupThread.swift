//
//  GroupThread.swift
//  BookClubB
//
//  Created by YourName on 6/1/25.
//  Updated 6/10/25 to add an optional `authorUID` field.
//

import Foundation
import FirebaseFirestore

struct GroupThread: Identifiable {
    var id: String

    // The display‐name of whoever created this thread:
    let authorID: String        // from Firestore field “username”

    // The actual UID of the creator (so we can navigate to their profile):
    let authorUID: String?      // ← newly added

    let content: String         // from Firestore field “content”
    let timestamp: Date         // from Firestore field “createdAt”
    let likeCount: Int          // from Firestore field “likesCount”
    let replyCount: Int         // from Firestore field “repliesCount”
    let updatedAt: Date?        // optional Firestore field “updatedAt”, if present

    /// Parse a Firestore document into GroupThread.
    /// Now expects an optional “authorUID” key in addition to the existing fields.
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

        // Read “authorUID” if it was stored (older threads may not have this key)
        let authorUID = dict["authorUID"] as? String

        // Read “updatedAt” if present
        let updatedTS = dict["updatedAt"] as? Timestamp

        return GroupThread(
            id: id,
            authorID: authorID,
            authorUID: authorUID,                 // ← populate the new field
            content: content,
            timestamp: ts.dateValue(),
            likeCount: likeCount,
            replyCount: replyCount,
            updatedAt: updatedTS?.dateValue()
        )
    }

    /// Convert this GroupThread back into a Firestore‐compatible dictionary.
    /// When you create (or update) a thread, you should include “authorUID” here.
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "username":     authorID,                  // display‐name
            "content":      content,
            "createdAt":    Timestamp(date: timestamp),
            "likesCount":   likeCount,
            "repliesCount": replyCount
        ]

        // Include authorUID if it exists
        if let authorUID = authorUID {
            dict["authorUID"] = authorUID
        }

        // Include updatedAt if it exists
        if let updatedAt = updatedAt {
            dict["updatedAt"] = Timestamp(date: updatedAt)
        }

        return dict
    }
}
