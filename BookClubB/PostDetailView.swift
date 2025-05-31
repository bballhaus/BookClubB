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
                    .font(.title2)
                    .bold()

                Text("by \(post.author)")
                    .font(.subheadline)
                    .foregroundColor(.gray)

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
    let sample = Post(
        id: "abc123",
        data: [
            "author": "Bob",
            "title": "Sample Post",
            "body": "This is a test post body.",
            "timestamp": Timestamp(date: Date())
        ]
    )!
    NavigationView {
        PostDetailView(post: sample)
    }
}

