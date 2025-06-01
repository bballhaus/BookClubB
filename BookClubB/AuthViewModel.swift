//  AuthViewModel.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

class AuthViewModel: ObservableObject {
    @Published var user: FirebaseAuth.User?

    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            self?.user = firebaseUser
        }
    }

    deinit {
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
            print("Anonymous sign‐in succeeded: \(String(describing: result?.user.uid))")
        }
    }
    
    // Updated createUser method with username and Firestore saving
    func createUser(email: String, password: String, username: String) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                print("Error creating user: \(error.localizedDescription)")
                return
            }

            guard let user = result?.user else { return }

            // ───────────────────────────────────────────────────────────────
            // 1) Immediately set the displayName on the Auth user:
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = username
            changeRequest.commitChanges { profileError in
                if let profileError = profileError {
                    print("Error setting displayName: \(profileError.localizedDescription)")
                } else {
                    print("✅ displayName set to: \(username)")
                }
            }
            // ───────────────────────────────────────────────────────────────
            
            self?.user = user
            
            // 2) Save username and email to Firestore (so you can also read profile data later if needed)
            let db = Firestore.firestore()
            db.collection("users").document(user.uid).setData([
                "username": username,
                "email": email,
                "createdAt": Timestamp()
            ]) { error in
                if let error = error {
                    print("Error saving user data: \(error.localizedDescription)")
                } else {
                    print("User data saved successfully!")
                }
            }
            
            print("User created: \(email)")
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
