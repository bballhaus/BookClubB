//
//  UserProfile.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//

import Foundation
import FirebaseFirestore

struct UserProfile: Identifiable {
    var id: String                 // same as the document ID (uid)
    let username: String
    let email: String
    let profileImageURL: String    // URL to the user’s avatar
    let groupIDs: [String]         // groups the user belongs to
    let createdAt: Date

    // Initialize from Firestore data dictionary
    static func fromDictionary(_ dict: [String: Any], id: String) -> UserProfile? {
        guard
            let username = dict["username"] as? String,
            let email = dict["email"] as? String,
            let profileImageURL = dict["profileImageURL"] as? String,
            let groupIDs = dict["groupIDs"] as? [String],
            let timestamp = dict["createdAt"] as? Timestamp
        else {
            return nil
        }
        return UserProfile(
            id: id,
            username: username,
            email: email,
            profileImageURL: profileImageURL,
            groupIDs: groupIDs,
            createdAt: timestamp.dateValue()
        )
    }

    // Convert to a dictionary for writing/updating Firestore
    func toDictionary() -> [String: Any] {
        return [
            "username": username,
            "email": email,
            "profileImageURL": profileImageURL,
            "groupIDs": groupIDs,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
}
