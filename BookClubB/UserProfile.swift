//
//  UserProfile.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//

import Foundation

struct UserProfile: Identifiable {
    let id: String

    let username: String

    var displayName: String

    var profileImageURL: String

    let groupIDs: [String]

    static func fromDictionary(_ dict: [String: Any], id: String) -> UserProfile? {
        guard
            let username   = dict["username"]      as? String,
            let imageURL   = dict["profileImageURL"] as? String,
            let groupIDs   = dict["groupIDs"]      as? [String]
        else {
            return nil
        }

        let rawDisplay = dict["displayName"] as? String
        let computedDisplayName = (rawDisplay?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? rawDisplay!
            : username

        return UserProfile(
            id: id,
            username: username,
            displayName: computedDisplayName,
            profileImageURL: imageURL,
            groupIDs: groupIDs
        )
    }
}
