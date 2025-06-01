//
//  GroupPageView.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//

import SwiftUI
import Firebase
import FirebaseFirestore

struct GroupPageView: View {
    @State private var groups: [BookGroup] = []

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading) {

                    Text("Summer Reads")
                        .font(.title)
                        .bold()
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(groups) { group in
                                NavigationLink(destination: GroupDetailView(group: group)) {
                                    AsyncImage(url: URL(string: group.imageUrl)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 120, height: 180)
                                            .cornerRadius(10)
                                    } placeholder: {
                                        ProgressView()
                                            .frame(width: 120, height: 180)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    Text("My Current Reads")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            // Hardcoded "Hunger Games Book 1"
                            NavigationLink(destination: GroupDetailView(group: BookGroup(id: UUID().uuidString, title: "The Hunger Games", author: "Suzanne Collins", imageUrl: "https://example.com/hunger_games.jpg", memberCount: 10))) {
                                VStack {
                                    // ICON
                                    Image(systemName: "target") // SF Symbol for Hunger Games
                                        .font(.largeTitle)
                                        .foregroundColor(.orange)
                                        .padding(.bottom, 5)

                                    Image("hunger_games_cover") // Ensure you have this image in your Assets.xcassets
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 150, height: 220) // Increased size
                                        .cornerRadius(12)
                                        .shadow(radius: 5)

                                    Text("The Hunger Games")
                                        .font(.headline) // Changed to .headline for larger text
                                        .fontWeight(.medium)
                                        // Removed .lineLimit(1) to allow text to wrap
                                        .multilineTextAlignment(.center) // Center text if it wraps
                                        .fixedSize(horizontal: false, vertical: true) // Allows text to take up needed vertical space
                                        .padding(.top, 5)
                                }
                                .padding(10)
                                .background(Color.white)
                                .cornerRadius(15)
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                            }
                            .buttonStyle(PlainButtonStyle())

                            // Hardcoded "Harry Potter Book 1"
                            NavigationLink(destination: GroupDetailView(group: BookGroup(id: UUID().uuidString, title: "Harry Potter and the Sorcerer's Stone", author: "J.K. Rowling", imageUrl: "https://example.com/harry_potter.jpg", memberCount: 15))) {
                                VStack {
                                    // ICON
                                    Image(systemName: "sparkles") // SF Symbol for Harry Potter (magic)
                                        .font(.largeTitle)
                                        .foregroundColor(.purple)
                                        .padding(.bottom, 5)

                                    Image("harry_potter_cover") // Ensure you have this image in your Assets.xcassets
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 150, height: 220) // Increased size
                                        .cornerRadius(12)
                                        .shadow(radius: 5)

                                    Text("Harry Potter and the Sorcerer's Stone")
                                        .font(.headline) // Changed to .headline for larger text
                                        .fontWeight(.medium)
                                        // Removed .lineLimit(1) to allow text to wrap
                                        .multilineTextAlignment(.center) // Center text if it wraps
                                        .fixedSize(horizontal: false, vertical: true) // Allows text to take up needed vertical space
                                        .padding(.top, 5)
                                }
                                .padding(10)
                                .background(Color.white)
                                .cornerRadius(15)
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal)
                    }

                    Text("Threads You Might Be Interested In")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top)

                    // Placeholder avatars (static)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(["Cedric Diggory", "Night Court", "Haymitch Abernathy", "The Capitol"], id: \.self) { name in
                                VStack {
                                    Circle()
                                        .fill(Color.gray)
                                        .frame(width: 60, height: 60)
                                    Text(name)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top)
            }
            .navigationTitle("Groups")
        }
        .onAppear(perform: loadGroups)
    }

    func loadGroups() {
        let db = Firestore.firestore()
        db.collection("groups").getDocuments(completion: { snapshot, error in
            guard let documents = snapshot?.documents else { return }

            self.groups = documents.compactMap { doc -> BookGroup? in
                let data = doc.data()
                return BookGroup(
                    id: doc.documentID,
                    title: data["title"] as? String ?? "",
                    author: data["author"] as? String ?? "",
                    imageUrl: data["imageUrl"] as? String ?? "",
                    memberCount: data["memberCount"] as? Int ?? 0
                )
            }
        })
    }
}


#Preview {
    NavigationView {
        GroupPageView()
    }
}
