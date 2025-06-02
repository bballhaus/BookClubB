//
//  ProfileViewModel.swift
//  BookClubB
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import Combine
import UIKit  // for UIImage handling

class ProfileViewModel: ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var errorMessage: String?
    @Published var showingEditSheet = false

    /// Set to `true` once we know that `userProfile.id == currentUID`
    @Published var isViewingOwnProfile = false

    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private let viewingUsername: String?

    /// If `username` is `nil`, we fetch “my own” profile by UID.
    init(username: String? = nil) {
        self.viewingUsername = username
        fetchUserProfile()
    }

    private func fetchUserProfile() {
        if let lookupHandle = viewingUsername {
            // ── 1) LOOKUP ANOTHER USER BY THEIR IMMUTABLE HANDLE (“username”) ──
            db.collection("users")
                .whereField("username", isEqualTo: lookupHandle)
                .limit(to: 1)
                .getDocuments { [weak self] snapshot, error in
                    guard let self = self else { return }
                    if let error = error {
                        DispatchQueue.main.async {
                            self.errorMessage = "Failed to fetch profile: \(error.localizedDescription)"
                        }
                        return
                    }
                    if let doc = snapshot?.documents.first,
                       let profile = UserProfile.fromDictionary(doc.data(), id: doc.documentID) {
                        DispatchQueue.main.async {
                            self.userProfile = profile
                            self.setIsViewingOwnProfile()
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.errorMessage = "User “\(lookupHandle)” not found or data malformed."
                        }
                    }
                }

        } else {
            // ── 2) FETCH “MY OWN” PROFILE BY UID ──
            guard let currentUID = Auth.auth().currentUser?.uid else {
                DispatchQueue.main.async {
                    self.errorMessage = "Not signed in."
                }
                return
            }

            let ref = db.collection("users").document(currentUID)
            ref.getDocument { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to fetch my profile: \(error.localizedDescription)"
                    }
                    return
                }
                if let data = snapshot?.data(),
                   let profile = UserProfile.fromDictionary(data, id: currentUID) {
                    DispatchQueue.main.async {
                        self.userProfile = profile
                        self.setIsViewingOwnProfile()
                    }
                } else {
                    DispatchQueue.main.async {
                        self.errorMessage = "My user document not found or data malformed."
                    }
                }
            }
        }
    }

    /// After we load `userProfile`, check if its `id` (UID) matches the current auth UID.
    private func setIsViewingOwnProfile() {
        if let profile = userProfile,
           let currentUID = Auth.auth().currentUser?.uid {
            isViewingOwnProfile = (profile.id == currentUID)
        } else {
            isViewingOwnProfile = false
        }
    }

    // MARK: – Edit Display Name

    /// Call this to update both Auth.displayName and Firestore’s “displayName” field.
    func updateDisplayName(to newDisplayName: String) {
        guard let currentUser = Auth.auth().currentUser else { return }
        let currentUID = currentUser.uid

        // 1) Update Auth.displayName so that Auth.currentUser?.displayName stays in sync
        let changeRequest = currentUser.createProfileChangeRequest()
        changeRequest.displayName = newDisplayName
        changeRequest.commitChanges { [weak self] error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.errorMessage = "Failed to update Auth displayName: \(error.localizedDescription)"
                }
                return
            }
            // 2) Update Firestore “displayName”
            self?.db.collection("users").document(currentUID).updateData([
                "displayName": newDisplayName
            ]) { [weak self] err in
                if let err = err {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Failed to update Firestore displayName: \(err.localizedDescription)"
                    }
                    return
                }
                // 3) Immediately update our local model so the UI refreshes
                DispatchQueue.main.async {
                    self?.userProfile?.displayName = newDisplayName
                }
            }
        }
    }

    // MARK: – Upload Profile Image

    /// Call this to upload a new UIImage to Firebase Storage, then write its URL into Firestore.
    func uploadProfileImage(_ image: UIImage) {
        guard let currentUser = Auth.auth().currentUser else { return }
        let currentUID = currentUser.uid
        let ref = storage.reference().child("profile_images/\(currentUID).jpg")
        guard let imageData = image.jpegData(compressionQuality: 0.4) else { return }

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        ref.putData(imageData, metadata: metadata) { [weak self] _, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.errorMessage = "Failed to upload image: \(error.localizedDescription)"
                }
                return
            }
            ref.downloadURL { [weak self] url, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Failed to get download URL: \(error.localizedDescription)"
                    }
                    return
                }
                guard let downloadURL = url else { return }
                // 2) Update Firestore’s “profileImageURL” field
                self?.db.collection("users").document(currentUID).updateData([
                    "profileImageURL": downloadURL.absoluteString
                ]) { [weak self] firestoreError in
                    if let firestoreError = firestoreError {
                        DispatchQueue.main.async {
                            self?.errorMessage = "Failed to save image URL: \(firestoreError.localizedDescription)"
                        }
                        return
                    }
                    // 3) Update our local model so ProfileView refreshes immediately
                    DispatchQueue.main.async {
                        if var profile = self?.userProfile {
                            profile.profileImageURL = downloadURL.absoluteString
                            self?.userProfile = profile
                        }
                    }
                }
            }
        }
    }
}
