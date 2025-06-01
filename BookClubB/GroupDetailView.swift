//
//  GroupDetailView.swift
//  BookClubB
//
//  Created by Irene Lin on 5/31/25.
//

import SwiftUI

struct GroupDetailView: View {
    var group: BookGroup

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(group.title)
                    .font(.title)
                    .bold()
                Spacer()
            }

            Text(group.author)
                .foregroundColor(.secondary)

            Text("\(group.memberCount / 1000)k members")
                .font(.subheadline)
                .padding(.vertical, 2)

            Button(action: {
                // Handle join logic
            }) {
                Text("Join")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }

            Divider()
                .padding(.vertical)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    GroupThreadView(username: "Brooke", content: "The 50th Hunger Games – also known as the Second Quarter Quell. Double the tributes, double the trauma.")
                    GroupThreadView(username: "Aliya", content: "Let’s talk about why SOTR could be the darkest – and most politically charged – book in the series.")
                }
                .padding()
            }

            Spacer()
        }
        .padding()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct GroupThreadView: View {
    var username: String
    var content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(username)
                .font(.subheadline)
                .bold()
            Text(content)
            HStack(spacing: 16) {
                Image(systemName: "heart")
                Image(systemName: "arrowshape.turn.up.right")
                Image(systemName: "paperplane")
            }
            .foregroundColor(.gray)
            .padding(.top, 4)
        }
    }
}

#Preview {
    GroupDetailView(group: BookGroup(
        id: "1",
        title: "Sample Group",
        author: "Author Name",
        imageUrl: "https://example.com/image.jpg",
        memberCount: 412000
    ))
}

