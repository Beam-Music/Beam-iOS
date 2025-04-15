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
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            VStack(spacing: 20) {
                Text("Beam")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .padding(.top, 50)
                
                Text("Welcome back to BeamApp, listen to your favorite music!")
                    .font(.body)
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .gray)
                    .padding(.bottom, 20)
                
                TextField("Email address", text: viewStore.binding(
                    get: \.username,
                    send: LoginFeature.Action.usernameChanged
                ))
                .padding()
                .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white)
                .cornerRadius(8)
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(colorScheme == .dark ? Color.purple : Color.gray.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 30)
                
                SecureField("Password", text: viewStore.binding(
                    get: \.password,
                    send: LoginFeature.Action.passwordChanged
                ))
                .padding()
                .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white)
                .cornerRadius(8)
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(colorScheme == .dark ? Color.purple : Color.gray.opacity(0.3), lineWidth: 1)
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
            .background(colorScheme == .dark ? Color.black : Color.white)
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(leading: BackButton(action: {
                self.presentationMode.wrappedValue.dismiss()
            }))
        }
    }
}
