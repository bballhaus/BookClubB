//
//  ProfileView.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 6/1/25.
//  Displays the current user’s personal profile, their groups, and their posts.
//

import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = true

    private let horizontalPadding: CGFloat = 16

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                // ── PROFILE HEADER ───────────────────────────────────────
                HStack(spacing: 16) {
                    // 1) Profile Image (if available, else placeholder)
                    if let urlString = viewModel.userProfile?.profileImageURL,
                       let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 80, height: 80)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                            case .failure:
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay(
                                        Image(systemName: "person.crop.circle.fill.badge.exclamationmark")
                                            .foregroundColor(.red)
                                    )
                                    .frame(width: 80, height: 80)
                            @unknown default:
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 80, height: 80)
                            }
                        }
                    } else {
                        // Placeholder if no profileImageURL
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "person.crop.circle")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.gray)
                            )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        // 2) “Name” (hard-coded for now)
                        Text("Name")
                            .font(.title2)
                            .bold()

                        // 3) Username (“@username” if available)
                        if let username = viewModel.userProfile?.username {
                            Text("@\(username)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("@unknown")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // 4) Sign Out button
                    Button(action: signOut) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 16)

                // ── FOLLOWERS / FOLLOWING PLACEHOLDER ────────────────────
                HStack(spacing: 24) {
                    VStack {
                        Text("0")
                            .font(.headline)
                        Text("Following")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    VStack {
                        Text("0")
                            .font(.headline)
                        Text("Followers")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 12)

                Divider()
                    .padding(.vertical, 8)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        // ── “Your Groups” SECTION ───────────────────────────────
                        HStack {
                            Text("Your Groups")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, horizontalPadding)

                        if viewModel.groups.isEmpty {
                            Text("You haven’t joined any groups yet.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, horizontalPadding)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(viewModel.groups) { group in
                                        NavigationLink(destination: GroupDetailView(groupID: group.id)) {
                                            GroupCardView(group: group)
                                                .frame(width: 140, height: 240)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal, horizontalPadding)
                            }
                            .frame(height: 260)
                        }

                        Divider()

                        // ── “Your Posts” SECTION ────────────────────────────────
                        HStack {
                            Text("Your Posts")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, horizontalPadding)

                        if viewModel.posts.isEmpty {
                            Text("You haven’t made any posts yet.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, horizontalPadding)
                        } else {
                            VStack(spacing: 16) {
                                ForEach(viewModel.posts) { post in
                                    NavigationLink(destination: PostDetailView(post: post)) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(post.title)
                                                .font(.subheadline)
                                                .bold()
                                                .foregroundColor(.primary)
                                            Text(post.body)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                            Text(post.timestamp, style: .date)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(UIColor.systemGray6))
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(.horizontal, horizontalPadding)
                                }
                            }
                        }

                        Spacer(minLength: 32)
                    }
                    .padding(.top, 0)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(
                // Show any error at bottom if needed
                Group {
                    if let err = viewModel.errorMessage {
                        Text("❌ \(err)")
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(8)
                            .padding(.bottom, 32)
                    }
                },
                alignment: .bottom
            )
        }
    }

    private func signOut() {
        do {
            try Auth.auth().signOut()
            isLoggedIn = false
        } catch {
            // Handle sign-out error if desired
        }
    }
}

// ───────────────────────────────────────────────────────────────────────────────
// Preview
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
