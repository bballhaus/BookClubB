//
//  UserProfile.swift
//  BookClubB
//

import Foundation

struct UserProfile: Identifiable {
    let id: String

    /// The immutable “@handle” (never edited via the UI)
    let username: String

    /// The editable display name (what shows as “Name” on the profile)
    var displayName: String

    /// URL (string) to the user’s profile image
    var profileImageURL: String

    /// List of group IDs the user belongs to
    let groupIDs: [String]

    static func fromDictionary(_ dict: [String: Any], id: String) -> UserProfile? {
        // 1) Always require “username” (the immutable handle), plus image+groups
        guard
            let username   = dict["username"]      as? String,
            let imageURL   = dict["profileImageURL"] as? String,
            let groupIDs   = dict["groupIDs"]      as? [String]
        else {
            return nil
        }

        // 2) “displayName” is now optional; if missing or empty, default back to username
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
