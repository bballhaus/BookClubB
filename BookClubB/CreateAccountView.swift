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
    @State private var password: String = ""
    @State private var username: String = ""   // Added username state

    var body: some View {
        VStack(spacing: 0) {

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
                    Text("Or log back in with your email to continue.")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

        
                }
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)

                // Username TextField (new)
                TextField("Username", text: $username)
                    .autocapitalization(.none)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                            .background(Color(white: 0.95))
                            .cornerRadius(8)
                    )
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
                SecureField("Password", text: $password)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                            .background(Color(white: 0.95))
                            .cornerRadius(8)
                    )
                    .padding(.bottom, 24)

                // Continue Button - pass username now
                Button(action: {
                    authVM.createUser(email: email, password: password, username: username)
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

            Spacer()
        }
        .background(Color.white.ignoresSafeArea())
    }
}

struct CreateAccountView_Previews: PreviewProvider {
    static var previews: some View {
        CreateAccountView()
            .environmentObject(AuthViewModel())
    }
}
