//
//  PostDetailView.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//

import SwiftUI
import FirebaseFirestore

struct PostDetailView: View {
    let post: Post

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(post.title)
                    .font(.title2).bold()

                // “by <post.author>” uses profileView(username: post.author)
                NavigationLink(destination: ProfileView(username: post.author)) {
                    Text("by \(post.author)")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())

                Divider()

                Text(post.body)
                    .font(.body)

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Post")
    }
}
