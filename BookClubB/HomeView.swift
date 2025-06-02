//
//  HomeView.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//  Updated 6/10/25 so that tapping “by <author>” passes the author’s username
//  into ProfileView(username:), rather than showing your own profile.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = PostViewModel()
    @State private var showingCreate = false

    var body: some View {
        VStack {
            if viewModel.posts.isEmpty {
                VStack {
                    ProgressView()
                    Text("Loading posts…")
                        .foregroundColor(.gray)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.posts) { post in
                        VStack(alignment: .leading, spacing: 8) {
                            // The entire card navigates to PostDetailView
                            NavigationLink(destination: PostDetailView(post: post)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(post.title)
                                        .font(.headline)

                                    // Tapping “by <author>” → ProfileView(username: post.author)
                                    NavigationLink(destination: ProfileView(username: post.author)) {
                                        Text("by \(post.author)")
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(PlainButtonStyle())

                                    Text(post.body)
                                        .font(.body)
                                        .lineLimit(2)

                                    Text(post.timestamp, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingCreate = true }) {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showingCreate) {
            CreatePostView()
        }
    }
}

#Preview {
    NavigationView {
        HomeView()
    }
}
