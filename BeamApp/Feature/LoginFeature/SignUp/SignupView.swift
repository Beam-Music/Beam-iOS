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
                Text("회원가입")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .padding(.bottom, 20)

                // --- 회원가입 입력 필드 ---
                TextField("사용자 이름", text: viewStore.binding(
                        get: \.username,
                        send: SignupFeature.Action.usernameChanged
                    ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textContentType(.username)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .disabled(viewStore.isVerified)
                    .padding(.horizontal, 30)
                    
                TextField("이메일", text: viewStore.binding(
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
                    
                SecureField("비밀번호", text: viewStore.binding(
                        get: \.password,
                        send: SignupFeature.Action.passwordChanged
                    ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textContentType(.newPassword)
                .disabled(viewStore.isVerified)
                    .padding(.horizontal, 30)
                    
                // 회원가입 요청 버튼
                Button(action: { viewStore.send(.signupButtonTapped) }) {
                    Text("가입 요청 및 인증 메일 받기")
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

                    Text("이메일로 전송된 인증 코드를 입력하세요.")
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? .white : .black)

                    TextField("인증 코드", text: viewStore.binding(
                            get: \.verificationCode,
                            send: SignupFeature.Action.verificationCodeChanged
                        ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .disabled(viewStore.isLoading)
                        .padding(.horizontal, 30)
                        
                    Button(action: { viewStore.send(.verifyButtonTapped) }) {
                        Text("이메일 인증")
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
                    ProgressView("처리 중...")
                        .tint(.purple)
                }

                if let errorMessage = viewStore.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.top)
            }

                if viewStore.isLoggedIn {
                    Text("회원가입 및 인증 완료!")
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
        }
    }
}
