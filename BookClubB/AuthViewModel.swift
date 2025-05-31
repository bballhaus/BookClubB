//
//  AuthViewModel.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//
import Foundation
import FirebaseAuth
import Combine

/// A very simple authentication‐state view model that publishes
/// whether there is a `currentUser`. You can expand this later to
/// support sign‐in / sign‐out logic as needed.
class AuthViewModel: ObservableObject {
    // Published property to track if a user is signed in
    @Published var user: FirebaseAuth.User?

    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        // Listen to auth state changes:
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            self?.user = firebaseUser
        }
    }

    deinit {
        // Detach listener when the object is deallocated
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    /// Example sign‐in function (you can wire this into a "Continue" button)
    func signInAnonymously() {
        Auth.auth().signInAnonymously { result, error in
            if let error = error {
                print("Failed to sign in anonymously: \(error.localizedDescription)")
                return
            }
            // On success, `user` will be set automatically via the listener above
            print("Anonymous sign‐in succeeded: \(String(describing: result?.user.uid))")
        }
    }

    /// Example sign‐out function
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.user = nil
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}

