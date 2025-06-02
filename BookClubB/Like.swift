//
//  Like.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//

import Foundation
import FirebaseFirestore

struct Like: Identifiable {
    var id: String            
    let userID: String
    let timestamp: Date

    static func fromDictionary(_ dict: [String: Any], id: String) -> Like? {
        guard
            let userID = dict["userID"] as? String,
            let ts = dict["timestamp"] as? Timestamp
        else {
            return nil
        }
        return Like(
            id: id,
            userID: userID,
            timestamp: ts.dateValue()
        )
    }

    func toDictionary() -> [String: Any] {
        return [
            "userID": userID,
            "timestamp": Timestamp(date: timestamp)
        ]
    }
}
