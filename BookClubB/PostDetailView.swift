//
//  PostDetailView.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//  Updated 6/10/25 so that tapping the author’s name opens ProfileView(username:).
//

import SwiftUI
import FirebaseFirestore

struct PostDetailView: View {
    let post: Post

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(post.title)
                    .font(.title2)
                    .bold()

                // Tapping “by <author>” → ProfileView(username: post.author)
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

#Preview {
    let sampleData: [String: Any] = [
        "author": "Bob",
        "title": "Sample Post",
        "body": "This is a test post body.",
        "timestamp": Timestamp(date: Date())
    ]
    let samplePost = Post(id: "abc123", data: sampleData)!

    NavigationView {
        PostDetailView(post: samplePost)
    }
}
