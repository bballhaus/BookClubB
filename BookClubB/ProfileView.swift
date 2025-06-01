//
//  ProfileView.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//

// ProfileView.swift
import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @State private var errorMessage: String?
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = true  // Optional: depends on your login state management

    var body: some View {
        VStack {
            Text("Profile placeholder")
                .padding()

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: signOut) {
                    Text("Sign Out")
                        .foregroundColor(.red)
                }
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            isLoggedIn = false  // Update this based on your login state logic
        } catch {
            errorMessage = "Sign-out failed: \(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationView {
        ProfileView()
    }
}
