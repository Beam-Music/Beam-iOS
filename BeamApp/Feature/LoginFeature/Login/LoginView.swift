//
//  LoginView.swift
//  BeamApp
//
//  Created by freed on 10/15/24.
//

import SwiftUI
import ComposableArchitecture

struct LoginView: View {
    let store: StoreOf<LoginFeature>
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.pink.opacity(0.7), Color.purple.opacity(0.7), Color.orange.opacity(0.7)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            WithViewStore(self.store, observe: { $0 }) { viewStore in
                VStack(spacing: 20) {
                    HStack {
                        Spacer()
                        Button(action: {
                            self.presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(16)
                        }
                    }
                    TextField("Email address", text: viewStore.binding(
                        get: \.username,
                        send: LoginFeature.Action.usernameChanged
                    ))
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
                    .foregroundColor(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.purple, lineWidth: 1)
                    )
                    .padding(.horizontal, 30)
                    SecureField("Password", text: viewStore.binding(
                        get: \.password,
                        send: LoginFeature.Action.passwordChanged
                    ))
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
                    .foregroundColor(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.purple, lineWidth: 1)
                    )
                    .padding(.horizontal, 30)
                    Button(action: {
                        viewStore.send(.loginButtonTapped)
                    }) {
                        Text("Sign in")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.horizontal, 30)
                    }
                    .disabled(viewStore.isLoading)
                    if viewStore.isLoading {
                        ProgressView()
                            .tint(.purple)
                    }
                    if let errorMessage = viewStore.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                    Spacer()
                }
                .padding()
                .navigationBarBackButtonHidden(true)
                .navigationBarItems(leading: BackButton(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }))
            }
        }
    }
}
