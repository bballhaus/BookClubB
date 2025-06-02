//
//  HomeView.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//  Updated 6/1/25 to remove the `username` argument from ProfileView.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = PostViewModel()
    @State private var showingCreate = false

    var body: some View {
        VStack {
            if viewModel.posts.isEmpty {
                // Show a loading spinner (or "no posts yet") if empty
                VStack {
                    ProgressView()
                    Text("Loading posts…")
                        .foregroundColor(.gray)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.posts) { post in
                    NavigationLink(destination: PostDetailView(post: post)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(post.title)
                                .font(.headline)

                            // <<— changed: remove `username:` argument
                            NavigationLink(destination: ProfileView()) {
                                Text("by \(post.author)")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }

                            Text(post.body)
                                .font(.body)
                                .lineLimit(2)

                            Text(post.timestamp, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                    // The outer NavigationLink still navigates to the full PostDetailView
                    .buttonStyle(PlainButtonStyle())
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
