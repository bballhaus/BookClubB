//
//  ProfileView.swift
//  BookClubB
//
//  Updated 6/◻️/25: Always show a circle with the first letter of `username`.
//

import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    /// If `viewingUsername` is nil, we show the signed-in user’s own profile (fetched by UID).
    /// Otherwise, we look up that other user’s profile by their immutable handle (“username”).
    let viewingUsername: String?

    @StateObject private var viewModel: ProfileViewModel
    @State private var isLoggedOut = false

    init(username: String? = nil) {
        self.viewingUsername = username
        _viewModel = StateObject(wrappedValue: ProfileViewModel(username: username))
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                // ── PROFILE HEADER ──────────────────────────────────────────
                if let profile = viewModel.userProfile {
                    HStack(spacing: 16) {
                        // ── Always show a circle with first letter of `profile.username` ──
                        let firstLetter = String(profile.username.prefix(1)).uppercased()
                        Circle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(firstLetter)
                                    .font(.largeTitle)
                                    .bold()
                                    .foregroundColor(.white)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            // 1) If they typed a distinct displayName, show it;
                            //    otherwise show their handle (username) in gray.
                            if !profile.displayName.isEmpty && profile.displayName != profile.username {
                                Text(profile.displayName)
                                    .font(.title2)
                                    .bold()
                            } else {
                                Text(profile.username)           // fallback
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(.secondary)
                            }

                            // 2) Then always show “@username”
                            Text("@\(profile.username)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // 3) If this is *my own* profile, show “Edit” + “Sign Out”
                        if viewModel.isViewingOwnProfile {
                            Button("Edit") {
                                viewModel.showingEditSheet = true
                            }
                            .sheet(isPresented: $viewModel.showingEditSheet) {
                                EditProfileView(
                                    initialDisplayName: profile.displayName,
                                    initialImageURL: profile.profileImageURL,
                                    onSave: { newName, newImage in
                                        // 1) Update display name
                                        viewModel.updateDisplayName(to: newName)
                                        // 2) If they picked a new image, upload it (still optional)
                                        if let img = newImage {
                                            viewModel.uploadProfileImage(img)
                                        }
                                    }
                                )
                            }

                            Button("Sign Out") {
                                signOut()
                            }
                            .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)

                    // ── SOME STATS PLACEHOLDER ─────────────────────────────────
                    HStack(spacing: 24) {
                        VStack {
                            Text("0") .font(.headline)
                            Text("Following") .font(.caption) .foregroundColor(.secondary)
                        }
                        VStack {
                            Text("0") .font(.headline)
                            Text("Followers") .font(.caption) .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    Divider().padding(.horizontal)

                    // ── GROUPS & RECENT POSTS PLACEHOLDER ──────────────────────
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Groups")
                                .font(.headline)
                                .padding(.horizontal)

                            if profile.groupIDs.isEmpty {
                                Text("No groups yet.")
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                            } else {
                                ForEach(profile.groupIDs, id: \.self) { groupID in
                                    Text("Group \(groupID)")
                                        .padding(.horizontal)
                                }
                            }

                            Divider().padding(.horizontal)

                            Text("Recent Posts")
                                .font(.headline)
                                .padding(.horizontal)

                            Text("No posts yet.")
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                        .padding(.bottom)
                    }

                } else if let error = viewModel.errorMessage {
                    // Show an error if loading failed
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                } else {
                    // Still loading
                    VStack {
                        ProgressView()
                        Text("Loading profile…")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
        }
        .fullScreenCover(isPresented: $isLoggedOut) {
            // After logout, show your root/login view (replace ContentView() with your actual login view)
            ContentView()
        }
    }

    private func signOut() {
        do {
            try Auth.auth().signOut()
            isLoggedOut = true
        } catch {
            // Optionally display an error message here
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
