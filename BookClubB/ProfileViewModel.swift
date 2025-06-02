//
//  ProfileViewModel.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class ProfileViewModel: ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var userGroups: [BookGroup] = []
    @Published var userPosts: [Post] = []
    @Published var errorMessage: String?
    @Published var showingEditSheet = false

    @Published var isViewingOwnProfile = false

    private let db = Firestore.firestore()
    private let viewingUsername: String?

    init(username: String? = nil) {
        self.viewingUsername = username
        fetchUserProfile()
    }

  
    
    private func fetchUserProfile() {
        if let lookupHandle = viewingUsername {

            
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
                            self.fetchUserGroups()
                            self.fetchUserPosts()
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.errorMessage = "User “\(lookupHandle)” not found."
                        }
                    }
                }
        } else {

            
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
                        self.fetchUserGroups()
                        self.fetchUserPosts()
                    }
                } else {
                    DispatchQueue.main.async {
                        self.errorMessage = "My user document not found or data malformed."
                    }
                }
            }
        }
    }


    private func setIsViewingOwnProfile() {
        if let profile = userProfile,
           let currentUID = Auth.auth().currentUser?.uid {
            isViewingOwnProfile = (profile.id == currentUID)
        } else {
            isViewingOwnProfile = false
        }
    }


    private func fetchUserGroups() {
        guard let profile = userProfile else { return }


        userGroups = []

        let groupIDs = profile.groupIDs

        guard !groupIDs.isEmpty else { return }

        let groupCollection = db.collection("groups")
        let dispatchGroup = DispatchGroup()
        var fetchedGroups: [BookGroup] = []

        for gid in groupIDs {
            dispatchGroup.enter()
            groupCollection.document(gid).getDocument { snapshot, error in
                defer { dispatchGroup.leave() }
                if let data = snapshot?.data(),
                   let group = BookGroup.fromDictionary(data, id: gid) {
                    fetchedGroups.append(group)
                }

            }
        }

        dispatchGroup.notify(queue: .main) {

            self.userGroups = fetchedGroups
        }
    }


    private func fetchUserPosts() {
        guard let profile = userProfile else { return }

        db.collection("posts")
            .whereField("authorUID", isEqualTo: profile.id)
            .order(by: "timestamp", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to fetch user’s posts: \(error.localizedDescription)"
                        self.userPosts = []
                    }
                    return
                }
                let docs = snapshot?.documents ?? []
                let fetched: [Post] = docs.compactMap { doc in
                    return Post(id: doc.documentID, data: doc.data())
                }
                DispatchQueue.main.async {
                    self.userPosts = fetched
                }
            }
    }


    
    func updateDisplayName(to newDisplayName: String) {
        guard let currentUser = Auth.auth().currentUser else { return }
        let currentUID = currentUser.uid


        let changeRequest = currentUser.createProfileChangeRequest()
        changeRequest.displayName = newDisplayName
        changeRequest.commitChanges { [weak self] error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.errorMessage = "Failed to update Auth displayName: \(error.localizedDescription)"
                }
                return
            }

            self?.db.collection("users").document(currentUID).updateData([
                "displayName": newDisplayName
            ]) { [weak self] err in
                if let err = err {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Failed to update Firestore displayName: \(err.localizedDescription)"
                    }
                    return
                }
                DispatchQueue.main.async {
                    self?.userProfile?.displayName = newDisplayName
                }
            }
        }
    }

    func uploadProfileImage(_ image: UIImage) {
        //
    }
}
