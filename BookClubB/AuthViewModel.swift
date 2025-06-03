//
// AuthViewModel.swift
// BookClubB
//
// Created by Irene Lin on 5/31/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

class AuthViewModel: ObservableObject {
    @Published var user: FirebaseAuth.User?
    @Published var errorMessage: String?
    @Published var isUserAuthenticated: Bool = false    // <-- Add this

    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            self?.user = firebaseUser
            if let user = firebaseUser {
                print("User signed in: \(user.email ?? "No Email")")
                DispatchQueue.main.async {
                    self?.isUserAuthenticated = true    // <-- Keep this in sync with user state
                }
            } else {
                print("User signed out.")
                DispatchQueue.main.async {
                    self?.isUserAuthenticated = false
                }
            }
        }
    }

    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // Create new user (immutable value)
    func createUser(email: String, password: String, username: String) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Error creating user: \(error.localizedDescription)"
                    self.isUserAuthenticated = false    // <-- Reset on failure
                }
                return
            }

            guard let user = result?.user else { return }

            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = username
            changeRequest.commitChanges { profileError in
                if let profileError = profileError {
                    print("Error setting Auth.displayName: \(profileError.localizedDescription)")
                }
            }

            let db = Firestore.firestore()
            let data: [String: Any] = [
                "username":        username,
                "email":           email,
                "profileImageURL": "",
                "groupIDs":        [],
                "createdAt":       Timestamp(date: Date())
            ]

            db.collection("users").document(user.uid).setData(data) { err in
                DispatchQueue.main.async {
                    if let err = err {
                        self.errorMessage = "Error saving user data: \(err.localizedDescription)"
                        self.isUserAuthenticated = false    // <-- Reset on failure
                    } else {
                        print("User data saved successfully!")
                        self.isUserAuthenticated = true     // <-- Success! Navigate now
                    }
                }
            }

            print("User created: \(email)")
        }
    }

    func signIn(email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.errorMessage = "Failed to sign in: \(error.localizedDescription)"
                    self?.isUserAuthenticated = false
                }
            } else {
                print("Signed in as \(result?.user.email ?? "Unknown")")
                DispatchQueue.main.async {
                    self?.isUserAuthenticated = true
                }
            }
        }
    }

    func signInAnonymously() {
        Auth.auth().signInAnonymously { [weak self] result, error in
            if let error = error {
                print("Failed to sign in anonymously: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.isUserAuthenticated = false
                }
                return
            }
            print("Anonymous sign-in succeeded: \(String(describing: result?.user.uid))")
            DispatchQueue.main.async {
                self?.isUserAuthenticated = true
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            DispatchQueue.main.async {
                self.user = nil
                self.isUserAuthenticated = false
            }
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}
