//
//  BookClubBApp.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//
import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct BookClubBApp: App {
    // 1) Create an instance of your AuthViewModel here:
    @StateObject private var authVM = AuthViewModel()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authVM.user == nil {
                    // 2) No signed‐in user → present CreateAccountView first
                    CreateAccountView()
                        .environmentObject(authVM)
                } else {
                    // 3) User is signed in → show your normal TabView
                    MainTabView()
                        .environmentObject(authVM)
                }
            }
        }
    }
}
