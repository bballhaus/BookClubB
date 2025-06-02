//
//  ProfileView.swift
//  BookClubB
//
//  Created by ChatGPT on 6/1/25.
//  Updated 6/12/25 to show each group’s title & cover image,
//  and to list the user’s actual posts under “Recent Posts.”
//

import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    /// If `viewingUsername` is nil, show the signed-in user’s own profile.
    /// Otherwise, look up that other user by handle (“username”).
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
                        // ── Letter‐avatar on a light‐green circle ──
                        let first = String(profile.username.prefix(1)).uppercased()
                        Circle()
                            .fill(Color.green.opacity(0.3))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(first)
                                    .font(.largeTitle)
                                    .bold()
                                    .foregroundColor(.white)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            // 1) Display “displayName” if it’s not empty & not same as handle
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

                            // 2) Always show “@username”
                            Text("@\(profile.username)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // 3) If viewing own profile, show “Edit” + “Sign Out”
                        if viewModel.isViewingOwnProfile {
                            Button("Edit") {
                                viewModel.showingEditSheet = true
                            }
                            .sheet(isPresented: $viewModel.showingEditSheet) {
                                EditProfileView(
                                    initialDisplayName: profile.displayName,
                                    initialImageURL: profile.profileImageURL
                                ) { newName, newImage in
                                    viewModel.updateDisplayName(to: newName)
                                    if let img = newImage {
                                        viewModel.uploadProfileImage(img)
                                    }
                                }
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

                    // ── GROUPS SECTION ─────────────────────────────────────────
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Groups")
                                .font(.headline)
                                .padding(.horizontal)

                            if viewModel.userGroups.isEmpty {
                                Text("No groups yet.")
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                            } else {
                                // Show each group’s cover image + title
                                ForEach(viewModel.userGroups) { group in
                                    NavigationLink(destination: GroupDetailView(groupID: group.id)) {
                                        HStack(spacing: 12) {
                                            AsyncImage(url: URL(string: group.imageUrl)) { phase in
                                                switch phase {
                                                case .empty:
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .fill(Color.gray.opacity(0.1))
                                                        .frame(width: 50, height: 50)
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 50, height: 50)
                                                        .clipped()
                                                        .cornerRadius(6)
                                                case .failure:
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .fill(Color.red.opacity(0.1))
                                                        .frame(width: 50, height: 50)
                                                @unknown default:
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .fill(Color.gray.opacity(0.1))
                                                        .frame(width: 50, height: 50)
                                                }
                                            }

                                            Text(group.title)
                                                .font(.subheadline)
                                                .foregroundColor(.primary)

                                            Spacer()
                                        }
                                        .padding(.vertical, 4)
                                        .padding(.horizontal)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }

                            Divider().padding(.horizontal)

                            // ── RECENT POSTS SECTION ─────────────────────────────────
                            Text("Recent Posts")
                                .font(.headline)
                                .padding(.horizontal)

                            if viewModel.userPosts.isEmpty {
                                Text("No posts yet.")
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                            } else {
                                ForEach(viewModel.userPosts) { post in
                                    NavigationLink(destination: PostDetailView(post: post)) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(post.title)
                                                .font(.subheadline)
                                                .bold()
                                                .foregroundColor(.primary)

                                            Text(post.timestamp, style: .date)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 6)
                                        .padding(.horizontal)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
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
            // After logout, show the root/login view
            ContentView()
        }
    }

    private func signOut() {
        do {
            try Auth.auth().signOut()
            isLoggedOut = true
        } catch {
            // Optionally handle error
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
