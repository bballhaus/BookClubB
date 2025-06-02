//
//  HomeView.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//  Modified 6/2/25 so that each post’s “avatar” is now a light‐green circle
//  containing the first uppercase letter of post.author (the username).
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = PostViewModel()
    @State private var showingCreate = false

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.posts) { post in
                        NavigationLink(destination: PostDetailView(post: post)) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 12) {
                                    // ── Avatar: light‐green circle with first letter of username ──
                                    let first = String(post.author.prefix(1)).uppercased()
                                    Circle()
                                        .fill(Color.green.opacity(0.3))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Text(first)
                                                .font(.headline)
                                                .foregroundColor(.white)
                                        )

                                    VStack(alignment: .leading, spacing: 2) {
                                        // Tapping “by <username>” → ProfileView(username:)
                                        NavigationLink(destination: ProfileView(username: post.author)) {
                                            Text(post.author)
                                                .font(.subheadline)
                                                .bold()
                                                .foregroundColor(.blue)
                                        }
                                        .buttonStyle(PlainButtonStyle())

                                        Text(post.timestamp, style: .date)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()
                                }

                                Text(post.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text(post.body)
                                    .font(.body)
                                    .lineLimit(2)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(UIColor.systemBackground))
                                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                            )
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreate = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingCreate) {
                CreatePostView()
            }
            // We assume PostViewModel()’s init already begins listening for posts,
            // so no explicit viewModel.fetchPosts() call is needed here.
        }
    }
}

#Preview {
    NavigationView {
        HomeView()
    }
}
