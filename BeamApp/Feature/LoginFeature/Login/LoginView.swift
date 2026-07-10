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
    @State private var appeared = false
    
    var body: some View {
        ZStack {
            AppTheme.onboardingGradient
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
                    TextField("이메일", text: viewStore.binding(
                        get: \.email,
                        send: LoginFeature.Action.emailChanged
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
                    SecureField("패스워드", text: viewStore.binding(
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
                        Text("로그인 하기")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.horizontal, 30)
                    }
                    .scaleEffect(appeared ? 1 : 0.8)
                    .opacity(appeared ? 1 : 0)
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
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5), value: appeared)
                .onAppear {
                    viewStore.send(.reset)
                    withAnimation { appeared = true }
                }
                .onChange(of: viewStore.token) { token in
                    if token != nil {
                        self.presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
