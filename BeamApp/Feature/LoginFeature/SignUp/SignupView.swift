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
    
    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            VStack {
                TextField("Full name", text: viewStore.binding(
                    get: \.fullName,
                    send: SignupFeature.Action.fullNameChanged
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
            }
            .padding()
        }
    }
}
