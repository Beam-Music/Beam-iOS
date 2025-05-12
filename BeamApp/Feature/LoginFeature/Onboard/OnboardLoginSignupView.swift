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
import Combine

enum Agreement {
    case none, agree, disagree
}

struct OnboardSignupView: View {
    let store: StoreOf<SignupFeature>
    let onNext: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var didAutoAdvance = false
    @State private var agreement: Agreement = .none
    @State private var isVerifyButtonDisabled = false
    @State private var verifyButtonRemainingSeconds = 0
    @State private var verifyButtonTimer: Timer?
    @State private var isSignupButtonDisabled = false
    @State private var signupButtonRemainingSeconds = 0
    @State private var signupButtonTimer: Timer?
    
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
                    VStack(alignment: .leading, spacing: 8) {
                        Text("프라이버시 및 이용약관 동의")
                            .foregroundColor(.white)
                            .font(.subheadline)
                        HStack(spacing: 24) {
                            CheckBox(isChecked: agreement == .agree, label: "동의") {
                                agreement = .agree
                            }
                            CheckBox(isChecked: agreement == .disagree, label: "비동의") {
                                agreement = .disagree
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    ZStack {
                        HStack {
                            Spacer()
                            Text(isSignupButtonDisabled
                                ? String(format: "가입 요청 및 인증 메일 받기 (%d:%02d)", signupButtonRemainingSeconds / 60, signupButtonRemainingSeconds % 60)
                                : "가입 요청 및 인증 메일 받기")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(LinearGradient(gradient: Gradient(colors: [Color.purple, Color.pink]), startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(12)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !(
                            viewStore.isLoading ||
                            viewStore.username.isEmpty ||
                            viewStore.email.isEmpty ||
                            viewStore.password.isEmpty ||
                            viewStore.isVerified ||
                            agreement != .agree ||
                            isSignupButtonDisabled
                        ) {
                            viewStore.send(.signupButtonTapped)
                            isSignupButtonDisabled = true
                            signupButtonRemainingSeconds = 120
                            signupButtonTimer?.invalidate()
                            signupButtonTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
                                if signupButtonRemainingSeconds > 0 {
                                    signupButtonRemainingSeconds -= 1
                                }
                                if signupButtonRemainingSeconds == 0 {
                                    isSignupButtonDisabled = false
                                    timer.invalidate()
                                }
                            }
                        }
                    }
                    .disabled(
                        viewStore.isLoading ||
                        viewStore.username.isEmpty ||
                        viewStore.email.isEmpty ||
                        viewStore.password.isEmpty ||
                        viewStore.isVerified ||
                        agreement != .agree ||
                        isSignupButtonDisabled
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
                            title: isVerifyButtonDisabled
                                ? String(format: "이메일 인증 (%d:%02d)", verifyButtonRemainingSeconds / 60, verifyButtonRemainingSeconds % 60)
                                : "이메일 인증",
                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                            action: {
                                viewStore.send(.verifyButtonTapped)
                                isVerifyButtonDisabled = true
                                verifyButtonRemainingSeconds = 120
                                verifyButtonTimer?.invalidate()
                                verifyButtonTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
                                    if verifyButtonRemainingSeconds > 0 {
                                        verifyButtonRemainingSeconds -= 1
                                    }
                                    if verifyButtonRemainingSeconds == 0 {
                                        isVerifyButtonDisabled = false
                                        timer.invalidate()
                                    }
                                }
                            }
                        )
                        .disabled(viewStore.isLoading || viewStore.verificationCode.isEmpty || isVerifyButtonDisabled)
                        .padding(.horizontal, 30)
                    }
                    if viewStore.isLoading {
                        ProgressView("처리 중...")
                            .tint(.purple)
                    }
                    Spacer(minLength: 40)
                    // Button("다음 →", action: onNext)
                    //     .font(.headline)
                    //     .frame(maxWidth: .infinity)
                    //     .padding()
                    //     .background(Color.white.opacity(0.7))
                    //     .foregroundColor(.purple)
                    //     .cornerRadius(12)
                    //     .padding(.horizontal, 32)
                }
                .padding()
                .background(Color.clear)
            }
            .keyboardAdaptive()
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .onChange(of: viewStore.isVerified) { isVerified in
                if isVerified && !didAutoAdvance {
                    didAutoAdvance = true
                    onNext()
                }
            }
            .onDisappear {
                signupButtonTimer?.invalidate()
                verifyButtonTimer?.invalidate()
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
        HStack {
            TextField("", text: $text)
                .keyboardType(keyboardType)
                .foregroundColor(.white)
                .placeholder(when: text.isEmpty) {
                    Text(placeholder)
                        .foregroundColor(.white.opacity(0.5))
                }
            Spacer(minLength: 0)
        }
        .padding(.leading, 24)
        .padding([.top, .bottom, .trailing], 12)
        .background(Color.white.opacity(0.15))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.7), lineWidth: 1)
        )
    }
}

struct CustomSecureField: View {
    let placeholder: String
    @Binding var text: String
    @State private var isSecure: Bool = true

    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    var body: some View {
        HStack {
            if isSecure {
                SecureField("", text: $text)
                    .foregroundColor(.white)
                    .placeholder(when: text.isEmpty) {
                        Text(placeholder)
                            .foregroundColor(.white.opacity(0.5))
                    }
            } else {
                TextField("", text: $text)
                    .foregroundColor(.white)
                    .placeholder(when: text.isEmpty) {
                        Text(placeholder)
                            .foregroundColor(.white.opacity(0.5))
                    }
            }
            Button(action: { isSecure.toggle() }) {
                Image(systemName: isSecure ? "eye.slash" : "eye")
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.trailing, 4)
            Spacer(minLength: 0)
        }
        .padding(.leading, 24)
        .padding([.top, .bottom, .trailing], 12)
        .background(Color.white.opacity(0.15))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.7), lineWidth: 1)
        )
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
    var isDisabled: Bool = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        gradient: isDisabled
                            ? Gradient(colors: [Color.gray.opacity(0.5), Color.gray])
                            : gradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                .contentShape(Rectangle())
        }
        .disabled(isDisabled)
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

struct CheckBox: View {
    var isChecked: Bool
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .foregroundColor(isChecked ? .purple : .white)
                Text(label)
                    .foregroundColor(.white)
                    .font(.subheadline)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Keyboard Adaptive Modifier
struct KeyboardAdaptive: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0
    let publisher = NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
        .merge(with: NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification))

    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .onReceive(publisher) { notification in
                if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    let screenHeight = UIScreen.main.bounds.height
                    if frame.origin.y >= screenHeight {
                        keyboardHeight = 0
                    } else {
                        keyboardHeight = frame.height
                    }
                } else {
                    keyboardHeight = 0
                }
            }
    }
}

extension View {
    func keyboardAdaptive() -> some View {
        self.modifier(KeyboardAdaptive())
    }
}
