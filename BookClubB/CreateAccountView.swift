//
//  CreateAccountView.swift
//  BookClubB
//
//  Created by Brooke Ballhaus on 5/31/25.
//

import SwiftUI
import FirebaseAuth

struct CreateAccountView: View {
    // 1) Read the AuthViewModel from the environment
    @EnvironmentObject var authVM: AuthViewModel

    @State private var email: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // MARK: – Logo
            Spacer().frame(height: 40)
            Image("BookClubLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 80)
                .padding(.bottom, 32)

            // MARK: – Title & Subtitle
            VStack(spacing: 8) {
                Text("Create an account")
                    .font(.title2).bold()

                Text("Enter your email to sign up for this app")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)

            // MARK: – Email TextField
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
                .padding(.horizontal, 32)
                .padding(.bottom, 24)

            // MARK: – Continue Button (Email)
            Button(action: {
                // Example placeholder action:
                // In a real flow you would send a magic link or call Firebase "createUser"
                authVM.signInAnonymously()
            }) {
                Text("Continue")
                    .foregroundColor(.white)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)

            // MARK: – Separator “or”
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.4))
                    .frame(height: 1)

                Text("  or  ")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                Rectangle()
                    .fill(Color.gray.opacity(0.4))
                    .frame(height: 1)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)

            // MARK: – Continue with Google
            Button(action: {
                // call your Google sign‐in logic here
                print("Continue with Google tapped")
            }) {
                HStack {
                    Image("GoogleLogo")
                        .resizable()
                        .renderingMode(.original)
                        .frame(width: 20, height: 20)

                    Text("Continue with Google")
                        .font(.headline)
                        .foregroundColor(Color.black)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(white: 0.95))
                .cornerRadius(8)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 12)

            // MARK: – Continue with Apple
            Button(action: {
                // call your Sign in with Apple logic here
                print("Continue with Apple tapped")
            }) {
                HStack {
                    Image(systemName: "applelogo")
                        .font(.system(size: 20, weight: .medium))

                    Text("Continue with Apple")
                        .font(.headline)
                        .foregroundColor(Color.black)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(white: 0.95))
                .cornerRadius(8)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)

            // MARK: – Terms & Privacy
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
            .padding(.horizontal, 32)

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
