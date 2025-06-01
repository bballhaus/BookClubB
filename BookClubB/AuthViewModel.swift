//
//  AuthViewModel.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//
import Foundation
import FirebaseAuth
import Combine


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
    
    func createUser(email: String, password: String) {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                print("Error creating user: \(error.localizedDescription)")
                return
            }

            self.user = result?.user
            print("User created: \(result?.user.email ?? "")")
        }
    }

    
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.user = nil
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}

