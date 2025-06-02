//
//  ProfileView.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//

import SwiftUI
import FirebaseAuth

struct ProfileView: View {

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
                HStack {
                    Spacer()
                    Image("BookClubLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 80)
                    Spacer()
                }
                .padding(.top, 8)
                .padding(.bottom, 12)
                
                if let profile = viewModel.userProfile {
                    HStack(spacing: 16) {
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
                            if !profile.displayName.isEmpty && profile.displayName != profile.username {
                                Text(profile.displayName)
                                    .font(.title2)
                                    .bold()
                            } else {
                                Text(profile.username)
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(.secondary)
                            }

                            Text("@\(profile.username)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

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

                    HStack(spacing: 40) {
                        VStack {
                            Text("\(viewModel.userGroups.count)")
                                .font(.headline)
                            Text("Groups")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        VStack {
                            let modCount = viewModel.userGroups.filter { group in
                                group.moderatorIDs.contains(profile.id)
                            }.count
                            Text("\(modCount)")
                                .font(.headline)
                            Text("Moderating")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    Divider().padding(.horizontal)

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
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                } else {
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
            ContentView()
        }
    }

    private func signOut() {
        do {
            try Auth.auth().signOut()
            isLoggedOut = true
        } catch {
            // handle error if needed
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
