//
//  BookGroup.swift
//  BookClubB
//
//  Created by YourName on 5/30/25.
//  Updated 6/10/25 to add `moderatorIDs`, `moderationQuestion`, `correctAnswer`.
//

import Foundation
import FirebaseFirestore

struct BookGroup: Identifiable {
    let id: String
    let title: String
    let bookAuthor: String
    let imageUrl: String
    let ownerID: String

    // NEW: an array of UIDs for every moderator of this group
    let moderatorIDs: [String]

    // The list of all member UIDs
    var memberIDs: [String]

    // When someone tries to join, they must answer this question:
    let moderationQuestion: String

    // The correct answer (case‐insensitive) to join
    let correctAnswer: String

    let createdAt: Date
    let updatedAt: Date

    /// Parse a Firestore document into BookGroup.
    static func fromDictionary(_ dict: [String: Any], id: String) -> BookGroup? {
        guard
            let title              = dict["title"]               as? String,
            let bookAuthor         = dict["bookAuthor"]          as? String,
            let imageUrl           = dict["imageUrl"]            as? String,
            let ownerID            = dict["ownerID"]             as? String,
            let memberIDs          = dict["memberIDs"]           as? [String],
            let moderationQuestion = dict["moderationQuestion"]  as? String,
            let correctAnswer      = dict["correctAnswer"]       as? String,
            let createdTS          = dict["createdAt"]           as? Timestamp,
            let updatedTS          = dict["updatedAt"]           as? Timestamp
        else {
            return nil
        }

        // Read "moderatorIDs" (if missing, default to empty array)
        let modIDs = dict["moderatorIDs"] as? [String] ?? []

        let createdAt = createdTS.dateValue()
        let updatedAt = updatedTS.dateValue()

        return BookGroup(
            id: id,
            title: title,
            bookAuthor: bookAuthor,
            imageUrl: imageUrl,
            ownerID: ownerID,
            moderatorIDs: modIDs,
            memberIDs: memberIDs,
            moderationQuestion: moderationQuestion,
            correctAnswer: correctAnswer,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// Convert this BookGroup to a Firestore‐compatible dictionary.
    func toDictionary() -> [String: Any] {
        return [
            "title":              title,
            "bookAuthor":         bookAuthor,
            "imageUrl":           imageUrl,
            "ownerID":            ownerID,
            "moderatorIDs":       moderatorIDs,
            "memberIDs":          memberIDs,
            "moderationQuestion": moderationQuestion,
            "correctAnswer":      correctAnswer,
            "createdAt":          Timestamp(date: createdAt),
            "updatedAt":          Timestamp(date: updatedAt)
        ]
    }
}
