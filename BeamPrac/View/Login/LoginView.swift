//
//  LoginView.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI

struct LoginView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @Binding var isLoggedIn: Bool

    var body: some View {
        VStack {
            TextField("Username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
            
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button("Login") {
                login()
            }
            .disabled(isLoading)
            
            if isLoading {
                ProgressView()
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
        .padding()
    }
    
    private func login() {
        isLoading = true
        errorMessage = nil
        
        // Simulating network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if self.username == "user" && self.password == "password" {
                self.isLoggedIn = true
            } else {
                self.errorMessage = "Invalid username or password"
            }
            self.isLoading = false
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(isLoggedIn: .constant(false))
    }
}
