//
//  BookClubBApp.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//
import FirebaseCore
import SwiftUI

@main
struct BookClubBApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}
