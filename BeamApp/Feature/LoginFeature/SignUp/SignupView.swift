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
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
            WithViewStore(self.store, observe: { $0 }) { viewStore in
            VStack(spacing: 20) {
                Text("Sign Up")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .padding(.bottom, 20)

                // --- Sign Up 입력 필드 ---
                TextField("Username", text: viewStore.binding(
                        get: \.username,
                        send: SignupFeature.Action.usernameChanged
                    ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textContentType(.username)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .disabled(viewStore.isVerified)
                    .padding(.horizontal, 30)
                    
                TextField("Email", text: viewStore.binding(
                        get: \.email,
                        send: SignupFeature.Action.emailChanged
                    ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .disabled(viewStore.isVerified)
                    .padding(.horizontal, 30)
                    
                SecureField("Password", text: viewStore.binding(
                        get: \.password,
                        send: SignupFeature.Action.passwordChanged
                    ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textContentType(.newPassword)
                .disabled(viewStore.isVerified)
                    .padding(.horizontal, 30)
                    
                // Sign Up 요청 버튼
                Button(action: { viewStore.send(.signupButtonTapped) }) {
                    Text("Request Sign-Up Email")
                        .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(
                    viewStore.isLoading || 
                    viewStore.username.isEmpty || 
                    viewStore.email.isEmpty || 
                    viewStore.password.isEmpty || 
                    viewStore.isVerified
                )
                .padding(.horizontal, 30)
                .padding(.top, 20)

                // --- 이메일 인증 섹션 ---
                if !viewStore.isVerified {
                    Divider()
                        .padding(.vertical)
                    .padding(.horizontal, 30)

                    Text("Enter the verification code sent to your email.")
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? .white : .black)

                    TextField("Verification Code", text: viewStore.binding(
                            get: \.verificationCode,
                            send: SignupFeature.Action.verificationCodeChanged
                        ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .disabled(viewStore.isLoading)
                        .padding(.horizontal, 30)
                        
                    Button(action: { viewStore.send(.verifyButtonTapped) }) {
                        Text("Verify Email")
                            .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(viewStore.isLoading || viewStore.verificationCode.isEmpty)
                        .padding(.horizontal, 30)
                }

                // --- 상태 표시 ---
                if viewStore.isLoading {
                    ProgressView("Processing...")
                        .tint(.purple)
                }

                if let errorMessage = viewStore.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.top)
            }

                if viewStore.isLoggedIn {
                    Text("Sign-up and verification complete!")
                        .foregroundColor(.green)
                        .padding(.top)
                }

                Spacer()
            }
            .padding()
            .background(colorScheme == .dark ? Color.black : Color.white)
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(leading: BackButton(action: {
                self.presentationMode.wrappedValue.dismiss()
            }))
            .onAppear {
                viewStore.send(.reset)
            }
        }
    }
}
