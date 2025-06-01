//
//  ThreadDetailView.swift
//  BookClubB
//
//  Created by YourName on 6/1/25.
//  Updated 6/1/25 to accept ThreadModel and pop back after reply.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ThreadDetailView: View {
    let groupID: String
    let thread: ThreadModel

    @StateObject private var viewModel = ThreadDetailViewModel()
    @State private var showingNewReplySheet: Bool = false
    @State private var didPostReply: Bool = false
    @State private var isMember: Bool = false

    @Environment(\.dismiss) private var dismissView

    var body: some View {
        VStack(spacing: 0) {
            // Parent thread’s header info
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: thread.avatarUrl)) { phase in
                        switch phase {
                        case .empty:
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 50, height: 50)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                        case .failure:
                            Circle()
                                .fill(Color.red.opacity(0.1))
                                .overlay(
                                    Image(systemName: "person.fill.exclamationmark")
                                        .foregroundColor(.red)
                                )
                                .frame(width: 50, height: 50)
                        @unknown default:
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 50, height: 50)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(thread.username)
                            .font(.headline)
                        Text(thread.createdAt, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                Text(thread.content)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 16) {
                    Image(systemName: "heart")
                    Text("\(thread.likesCount)")
                        .font(.subheadline)
                    Image(systemName: "bubble.right")
                    Text("\(thread.repliesCount)")
                        .font(.subheadline)
                    Spacer()
                }
                .foregroundColor(.gray)

                Divider()
            }
            .padding()

            // Replies list
            if let error = viewModel.errorMessage {
                Text("❌ \(error)")
                    .foregroundColor(.red)
                    .padding()
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.replies) { reply in
                            ReplyRowView(reply: reply)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }

            Divider()

            // “Add Reply” button (visible only if user is a member)
            if isMember {
                Button(action: {
                    showingNewReplySheet = true
                }) {
                    Text("Add Reply")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                }
                .sheet(isPresented: $showingNewReplySheet) {
                    NewReplyView(
                        groupID: groupID,
                        threadID: thread.id,
                        onReplyPosted: {
                            // Dismiss sheet, then pop ThreadDetailView
                            showingNewReplySheet = false
                            didPostReply = true
                        }
                    )
                }
            }
        }
        .navigationTitle("Thread")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.bind(toGroupID: groupID, threadID: thread.id)
            if let currentUser = Auth.auth().currentUser {
                let db = Firestore.firestore()
                db.collection("groups")
                  .document(groupID)
                  .getDocument { snapshot, _ in
                    if let data = snapshot?.data(),
                       let members = data["memberIDs"] as? [String] {
                        self.isMember = members.contains(currentUser.uid)
                    }
                  }
            }
        }
        .onChange(of: didPostReply) { posted in
            if posted {
                dismissView()
            }
        }
        .onDisappear {
            viewModel.detachListeners()
        }
    }
}

// ReplyRowView (unchanged from before)
struct ReplyRowView: View {
    let reply: Reply

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: reply.avatarUrl)) { phase in
                    switch phase {
                    case .empty:
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 40, height: 40)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    case .failure:
                        Circle()
                            .fill(Color.red.opacity(0.1))
                            .overlay(
                                Image(systemName: "person.fill.exclamationmark")
                                    .foregroundColor(.red)
                            )
                            .frame(width: 40, height: 40)
                    @unknown default:
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 40, height: 40)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(reply.username)
                        .font(.subheadline)
                        .bold()
                    Text(reply.createdAt, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Text(reply.content)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
        }
    }
}
