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
    
    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            ZStack {
                Image("background_image")
                    .resizable()
                    .scaledToFill()
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    .clipped()

                VStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sign in")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Welcome back to BeamApp, listen to your favorite music!")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 40)

                    VStack(spacing: 16) {
                        TextField("Email address", text: viewStore.binding(
                            get: \.username,
                            send: LoginFeature.Action.usernameChanged
                        ))
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        
                        SecureField("Password", text: viewStore.binding(
                            get: \.password,
                            send: LoginFeature.Action.passwordChanged
                        ))
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)

                        HStack {
                            Spacer()
                            Button(action: {
                            }) {
                                Text("Forgot your password?")
                                    .font(.caption)
                                    .foregroundColor(.purple)
                            }
                        }
                        .padding(.horizontal, 30)
                    }
                    .padding(.bottom, 40)

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
                    
                    HStack {
                        Text("Don't have an account?")
                            .foregroundColor(.white.opacity(0.8))
                        Button(action: {
                        }) {
                            Text("Sign up")
                                .foregroundColor(.purple)
                        }
                    }
                    .padding(.top, 16)
                    
                    Spacer()
                    if viewStore.isLoading {
                        ProgressView()
                    }
                    if let errorMessage = viewStore.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                .padding(.bottom, 40)
            }
            .edgesIgnoringSafeArea(.vertical)
        }
    }
}
