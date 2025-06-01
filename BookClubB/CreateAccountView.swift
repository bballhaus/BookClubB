//
//  CreateAccountView.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//

import SwiftUI
import FirebaseAuth

struct CreateAccountView: View {
    @EnvironmentObject var authVM: AuthViewModel

    @State private var email: String = ""
    @State private var password: String = "" // New state variable for password

    var body: some View {
        VStack(spacing: 0) {
            // Flexible Spacer to push content down from the top, centering it vertically
            Spacer()

            // MARK: – Logo
            Image("BookClubLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 80)
                .padding(.bottom, 32)


            VStack(spacing: 0) {
                // Title & Subtitle
                VStack(spacing: 8) {
                    Text("Create an account")
                        .font(.title2).bold()

                    Text("Enter your email to sign up for this app")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)

                // Email TextField
                TextField("email@domain.com", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                            .background(Color(white: 0.95))
                            .cornerRadius(8)
                    )
                    .padding(.bottom, 24)

                // Password SecureField
                SecureField("Password", text: $password) // Secure field for password input
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                            .background(Color(white: 0.95))
                            .cornerRadius(8)
                    )
                    .padding(.bottom, 24) // Padding below the password field

                // Continue Button
                Button(action: {
                    // Call createUser with both email and password
                    authVM.createUser(email: email, password: password)
                }) {
                    Text("Continue")
                        .foregroundColor(.white)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(8)
                }
                .padding(.bottom, 24)

                // Terms & Privacy
                VStack(spacing: 2) {
                    Text("By clicking continue, you agree to our")
                        .font(.footnote)
                        .foregroundColor(.gray)

                    HStack(spacing: 0) {
                        Text("Terms of Service")
                            .font(.footnote)
                            .foregroundColor(.blue)

                        Text(" and ")
                            .font(.footnote)
                            .foregroundColor(.gray)

                        Text("Privacy Policy")
                            .font(.footnote)
                            .foregroundColor(.blue)
                    }
                }
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            
            // A flexible spacer to push the content above it towards the top,
            // placing all content above this spacer.
            Spacer()
        }
        .background(Color.white.ignoresSafeArea())
    }
}

struct CreateAccountView_Previews: PreviewProvider {
    static var previews: some View {
        // Provide a dummy AuthViewModel for preview purposes:
        CreateAccountView()
            .environmentObject(AuthViewModel())
    }
}
