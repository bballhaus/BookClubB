//
//  PostDetailView.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//  Updated 6/1/25 to remove the `username` argument from ProfileView, since ProfileView() no longer takes parameters.
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

                // Tappable author name—now just opens the personal ProfileView()
                NavigationLink(destination: ProfileView()) {
                    Text("by \(post.author)")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }

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
