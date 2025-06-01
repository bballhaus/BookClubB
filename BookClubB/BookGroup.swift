//
//  BookGroup.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//

import Foundation
import FirebaseFirestore

struct BookGroup: Identifiable {
    var id: String                 // Firestore document ID
    let title: String              // The book’s title
    let bookAuthor: String         // The book’s author
    let ownerID: String            // UID of the user who created this group
    let imageUrl: String           // URL to the cover image
    let moderationQuestion: String // A question new joiners must answer
    let correctAnswer: String      // The “right answer” for that question
    var memberIDs: [String]        // UIDs of all members
    let createdAt: Date
    var updatedAt: Date?           // Now mutable so we can update it when someone joins

    /// Computed property to get the current number of members
    var memberCount: Int {
        return memberIDs.count
    }

    /// Convert Firestore dictionary → BookGroup
    static func fromDictionary(_ dict: [String: Any], id: String) -> BookGroup? {
        guard
            let title = dict["title"] as? String,
            let bookAuthor = dict["bookAuthor"] as? String,
            let ownerID = dict["ownerID"] as? String,
            let imageUrl = dict["imageUrl"] as? String,
            let moderationQuestion = dict["moderationQuestion"] as? String,
            let correctAnswer = dict["correctAnswer"] as? String,
            let memberIDs = dict["memberIDs"] as? [String],
            let createdTS = dict["createdAt"] as? Timestamp
        else {
            return nil
        }
        let updatedTS = dict["updatedAt"] as? Timestamp
        return BookGroup(
            id: id,
            title: title,
            bookAuthor: bookAuthor,
            ownerID: ownerID,
            imageUrl: imageUrl,
            moderationQuestion: moderationQuestion,
            correctAnswer: correctAnswer,
            memberIDs: memberIDs,
            createdAt: createdTS.dateValue(),
            updatedAt: updatedTS?.dateValue()
        )
    }
}

extension BookGroup {
    /// Firestore dictionary representation
    func asDictionary() -> [String: Any] {
        return [
            "title": title,
            "bookAuthor": bookAuthor,
            "ownerID": ownerID,
            "imageUrl": imageUrl,
            "moderationQuestion": moderationQuestion,
            "correctAnswer": correctAnswer,
            "memberIDs": memberIDs,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": updatedAt != nil ? Timestamp(date: updatedAt!) : NSNull()
        ]
    }
}
