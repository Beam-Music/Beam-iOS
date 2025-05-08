//
//  Untitled.swift
//  BeamApp
//
//  Created by anonymous on 5/8/25.
//

//
//  OnboardSignupView2.swift
//  BeamApp
//
//  Created by anonymous on 5/7/25.
//

import SwiftUI
import ComposableArchitecture

struct OnboardSignupView: View {
    let store: StoreOf<SignupFeature>
    let onNext: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var didAutoAdvance = false
    
    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            ScrollView {
                VStack(spacing: 24) {
                    Text("BEAM의 광야 속으로 들어와 볼래요?")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                    VStack(spacing: 16) {
                        CustomTextField("이름", text: viewStore.binding(
                            get: \.username,
                            send: SignupFeature.Action.usernameChanged
                        ))
                        CustomTextField("이메일 주소", text: viewStore.binding(
                            get: \.email,
                            send: SignupFeature.Action.emailChanged
                        ), keyboardType: .emailAddress)
                        CustomSecureField("비밀번호", text: viewStore.binding(
                            get: \.password,
                            send: SignupFeature.Action.passwordChanged
                        ))
                    }
                    .padding(.horizontal, 24)
                    HStack(spacing: 16) {
                        CustomToggle(label: "이용약관 동의", isOn: .constant(true))
                        CustomToggle(label: "개인정보 동의", isOn: .constant(true))
                    }
                    .padding(.horizontal, 24)
                    GradientButton(
                        title: "가입 요청 및 인증 메일 받기",
                        gradient: Gradient(colors: [Color.purple, Color.pink]),
                        action: { viewStore.send(.signupButtonTapped) }
                    )
                    .disabled(
                        viewStore.isLoading ||
                        viewStore.username.isEmpty ||
                        viewStore.email.isEmpty ||
                        viewStore.password.isEmpty ||
                        viewStore.isVerified
                    )
                    .padding(.horizontal, 30)
                    .padding(.top, 10)
                    if !viewStore.isVerified {
                        Divider()
                            .background(Color.white.opacity(0.3))
                            .padding(.vertical)
                            .padding(.horizontal, 30)
                        Text("이메일로 전송된 인증 코드를 입력하세요.")
                            .font(.headline)
                            .foregroundColor(.white)
                        CustomTextField("인증 코드", text: viewStore.binding(
                            get: \.verificationCode,
                            send: SignupFeature.Action.verificationCodeChanged
                        ), keyboardType: .numberPad)
                        .padding(.horizontal, 30)
                        GradientButton(
                            title: "이메일 인증",
                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                            action: { viewStore.send(.verifyButtonTapped) }
                        )
                        .disabled(viewStore.isLoading || viewStore.verificationCode.isEmpty)
                        .padding(.horizontal, 30)
                    }
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
                    Spacer(minLength: 40)
                }
                .padding()
                .background(Color.clear)
            }
            .onChange(of: viewStore.isVerified) { isVerified in
                if isVerified && !didAutoAdvance {
                    didAutoAdvance = true
                    onNext()
                }
            }
        }
    }
}

// MARK: - Custom Components

struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    init(_ placeholder: String, text: Binding<String>, keyboardType: UIKeyboardType = .default) {
        self.placeholder = placeholder
        self._text = text
        self.keyboardType = keyboardType
    }

    var body: some View {
        TextField("", text: $text)
            .keyboardType(keyboardType)
            .padding()
            .background(Color.white.opacity(0.15))
            .cornerRadius(12)
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.purple.opacity(0.7), lineWidth: 1)
            )
            .placeholder(when: text.isEmpty) {
                Text(placeholder)
                    .foregroundColor(.white.opacity(0.5))
            }
    }
}

struct CustomSecureField: View {
    let placeholder: String
    @Binding var text: String

    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    var body: some View {
        SecureField("", text: $text)
            .padding()
            .background(Color.white.opacity(0.15))
            .cornerRadius(12)
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.purple.opacity(0.7), lineWidth: 1)
            )
            .placeholder(when: text.isEmpty) {
                Text(placeholder)
                    .foregroundColor(.white.opacity(0.5))
            }
    }
}

struct CustomToggle: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(label)
                .foregroundColor(.white)
                .font(.subheadline)
        }
        .toggleStyle(SwitchToggleStyle(tint: Color.purple))
    }
}

struct GradientButton: View {
    let title: String
    let gradient: Gradient
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(gradient: gradient, startPoint: .leading, endPoint: .trailing)
                )
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }
}

// MARK: - Placeholder Modifier
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
