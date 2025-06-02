//
//  GroupThread.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//  Updated to add an `isModTagged` flag.
//

import Foundation
import FirebaseFirestore

struct GroupThread: Identifiable {
    var id: String

    let authorID: String

    let authorUID: String?

    let content: String
    let timestamp: Date
    let likeCount: Int
    let replyCount: Int
    let updatedAt: Date?

    let isModTagged: Bool


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

        let authorUID = dict["authorUID"] as? String

        let updatedTS = dict["updatedAt"] as? Timestamp

        let isModTagged = dict["isModTagged"] as? Bool ?? false

        return GroupThread(
            id: id,
            authorID: authorID,
            authorUID: authorUID,
            content: content,
            timestamp: ts.dateValue(),
            likeCount: likeCount,
            replyCount: replyCount,
            updatedAt: updatedTS?.dateValue(),
            isModTagged: isModTagged       
        )
    }

    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "username":     authorID,
            "content":      content,
            "createdAt":    Timestamp(date: timestamp),
            "likesCount":   likeCount,
            "repliesCount": replyCount,
            "isModTagged":  isModTagged
        ]

        if let authorUID = authorUID {
            dict["authorUID"] = authorUID
        }

        if let updatedAt = updatedAt {
            dict["updatedAt"] = Timestamp(date: updatedAt)
        }

        return dict
    }
}
