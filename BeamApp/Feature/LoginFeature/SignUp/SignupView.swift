//
//  SignupView.swift
//  BeamApp
//
//  Created by freed on 10/15/24.
//

import SwiftUI
import ComposableArchitecture

struct SignupView: View {
    let store: StoreOf<SignupFeature>
    @State private var navigateToHome = false
    
    var body: some View {
        NavigationView {
            WithViewStore(self.store, observe: { $0 }) { viewStore in
                VStack {
                    TextField("usename", text: viewStore.binding(
                        get: \.username,
                        send: SignupFeature.Action.usernameChanged
                    ))
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.horizontal, 30)
                    
                    TextField("Email address", text: viewStore.binding(
                        get: \.email,
                        send: SignupFeature.Action.emailChanged
                    ))
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.horizontal, 30)
                    
                    SecureField("Password", text: viewStore.binding(
                        get: \.password,
                        send: SignupFeature.Action.passwordChanged
                    ))
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.horizontal, 30)
                    
                    Button("Sign up") {
                        viewStore.send(.signupButtonTapped)
                    }
                    .disabled(viewStore.isLoading)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal, 30)
                    
                    if viewStore.isLoading {
                        ProgressView()
                    }
                    
                    if let errorMessage = viewStore.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                    if viewStore.isVerified == false {
                        TextField("Verification Code", text: viewStore.binding(
                            get: \.verificationCode,
                            send: SignupFeature.Action.verificationCodeChanged
                        ))
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                        .padding(.horizontal, 30)
                        
                        Button("Verify Code") {
                            viewStore.send(.verifyButtonTapped)
                        }
                        .disabled(viewStore.verificationCode.isEmpty || viewStore.isLoading)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal, 30)
                    }
                }
                .padding()
            }
        }
    }
}
