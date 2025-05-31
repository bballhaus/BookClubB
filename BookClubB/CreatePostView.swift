//
//  CreatePostView.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//

import SwiftUI

struct CreatePostView: View {
    @Environment(\.dismiss) var dismiss
    @State private var author = ""
    @State private var title = ""
    @State private var postBody = ""    // ← renamed from “body” to “postBody”
    @StateObject private var viewModel = PostViewModel()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Author")) {
                    TextField("Your name", text: $author)
                        .autocapitalization(.words)
                }
                Section(header: Text("Title")) {
                    TextField("Post title", text: $title)
                }
                Section(header: Text("Body")) {
                    TextEditor(text: $postBody)    // ← use $postBody here
                        .frame(height: 150)
                }
            }
            .navigationTitle("New Post")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.addPost(author: author, title: title, body: postBody)
                        dismiss()
                    }
                    .disabled(author.isEmpty || title.isEmpty || postBody.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    CreatePostView()
}
