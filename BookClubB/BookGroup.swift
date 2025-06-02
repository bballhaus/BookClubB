//
//  BookGroup.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//

import Foundation
import FirebaseFirestore

struct BookGroup: Identifiable {
    let id: String
    let title: String
    let bookAuthor: String
    let imageUrl: String
    let ownerID: String

    let moderatorIDs: [String]

    var memberIDs: [String]

    let moderationQuestion: String

    let correctAnswer: String

    let createdAt: Date
    let updatedAt: Date

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
