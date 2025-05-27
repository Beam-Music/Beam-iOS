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
import PhotosUI
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
    @State private var profileImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var showVerificationModal = false
    @State private var codeDigits: [String] = Array(repeating: "", count: 6)

    var body: some View {
        WithViewStore(self.store, observe: \.self) { viewStore in
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color(red: 0.91, green: 0.74, blue: 0.72), Color(red: 0.67, green: 0.62, blue: 0.87)]),
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        Text("BEAM의 광야 속으로\n가입하기")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .padding(.top, 32)

                        HStack(spacing: 0) {
                            ForEach(1...3, id: \.self) { idx in
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(idx == 1 ? Color.blue.opacity(0.2) : Color.white.opacity(0.4))
                                        .frame(width: 28, height: 28)
                                        .overlay(Text("\(idx)").foregroundColor(idx == 1 ? .blue : .gray).fontWeight(.bold))
                                    Text(idx == 1 ? "회원가입" : idx == 2 ? "아티스트 & 곡 선택" : "완료")
                                        .font(.caption)
                                        .foregroundColor(idx == 1 ? .blue : .white.opacity(0.7))
                                }
                                if idx < 3 {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.4))
                                        .frame(width: 40, height: 2)
                                }
                            }
                        }
                        .padding(.vertical, 24)

                        Button {
                            showImagePicker = true
                        } label: {
                            if let image = profileImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 110, height: 110)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 110, height: 110)
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.bottom, 24)
                        .photosPicker(isPresented: $showImagePicker, selection: Binding(
                            get: { nil },
                            set: { item in
                                if let item = item {
                                    Task {
                                        if let data = try? await item.loadTransferable(type: Data.self),
                                           let uiImage = UIImage(data: data) {
                                            profileImage = uiImage
                                        }
                                    }
                                }
                            }
                        ))

                        VStack(spacing: 18) {
                            CustomTextField("이름", text: viewStore.binding(
                                get: \.username,
                                send: SignupFeature.Action.usernameChanged
                            ))
                            HStack(spacing: 8) {
                                CustomTextField("이메일 주소", text: viewStore.binding(
                                    get: \.email,
                                    send: SignupFeature.Action.emailChanged
                                ), keyboardType: .emailAddress)
                                Button("인증하기") {
                                    if viewStore.errorMessage == "이미 가입된 이메일입니다. 새로운 인증 코드가 발송되었으니 이메일을 확인해주세요." {
                                        return
                                    }
                                    viewStore.send(.signupButtonTapped)
                                    showVerificationModal = true
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                                .background(viewStore.email.isEmpty || viewStore.isLoading ? Color.gray.opacity(0.5) : Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .disabled(viewStore.email.isEmpty || viewStore.isLoading)
                            }
                            if viewStore.errorMessage == "이미 가입된 이메일입니다. 새로운 인증 코드가 발송되었으니 이메일을 확인해주세요." {
                                Text(viewStore.errorMessage ?? "")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .padding(.top, 4)
                            }
                            CustomSecureField("비밀번호", text: viewStore.binding(
                                get: \.password,
                                send: SignupFeature.Action.passwordChanged
                            ))
                            CustomTextField("전화번호", text: viewStore.binding(
                                get: \.phone,
                                send: SignupFeature.Action.phoneChanged
                            ), keyboardType: .phonePad)
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 8)

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
                        .padding(.horizontal, 32)
                        .padding(.vertical, 8)

                        Button(action: {
                            if viewStore.isVerified {
                                onNext()
                            }
                            // onNext()
                        }) {
                            HStack {
                                Spacer()
                                Text("완료")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Image(systemName: "arrow.right")
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding()
                            .background(viewStore.isVerified ? Color.purple : Color.gray.opacity(0.5))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                        // .disabled(
                        //     viewStore.isLoading ||
                        //     viewStore.username.isEmpty ||
                        //     viewStore.email.isEmpty ||
                        //     viewStore.password.isEmpty ||
                        //     viewStore.phone.isEmpty ||
                        //     agreement != .agree ||
                        //     viewStore.errorMessage == "Invalid verification code or email" ||
                        //     !viewStore.isVerified
                        // )

                        Spacer()

                        HStack {
                            Text("계정이 이미 있으신가요?")
                                .foregroundColor(.white.opacity(0.7))
                            Button("로그인하기") {
                                // 로그인 이동 액션 필요시 구현
                            }
                            .foregroundColor(.white)
                            .underline()
                        }
                        .font(.footnote)
                        .padding(.bottom, 16)
                    }
                    .padding()
                }
                .keyboardAdaptive()
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            .sheet(isPresented: $showVerificationModal) {
                VerificationCodeModal(
                    code: $codeDigits,
                    onClose: { showVerificationModal = false },
                    onVerify: {
                        let code = codeDigits.joined()
                        viewStore.send(.verificationCodeChanged(code))
                        viewStore.send(.verifyButtonTapped)
                        showVerificationModal = false
                    }
                )
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

// 인증 코드 입력 모달
struct VerificationCodeModal: View {
    @Binding var code: [String]
    var onClose: () -> Void
    var onVerify: () -> Void
    @FocusState private var focusedIndex: Int?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.gray)
                        .padding()
                }
            }
            Text("이메일 인증 코드")
                .font(.title2.bold())
                .padding(.top, 8)
            Image(systemName: "envelope.open")
                .resizable()
                .scaledToFit()
                .frame(height: 120)
                .padding(.vertical, 12)
            Text("vertification code를 입력해주세요.")
                .foregroundColor(.gray)
                .padding(.bottom, 16)
            HStack(spacing: 12) {
                ForEach(0..<6) { idx in
                    TextField("", text: Binding(
                        get: { code[idx] },
                        set: { newValue in
                            if newValue.count <= 1 && newValue.allSatisfy({ $0.isNumber }) {
                                code[idx] = newValue
                            }
                        }
                    ))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.title)
                    .frame(width: 44, height: 48)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .focused($focusedIndex, equals: idx)
                }
            }
            .padding(.bottom, 24)
            .onAppear {
                focusedIndex = 0
            }
            Button("확인", action: onVerify)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal, 32)
            Spacer()
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.95, green: 0.82, blue: 0.78), Color(red: 0.93, green: 0.77, blue: 0.62)]),
                startPoint: .top, endPoint: .bottom
            )
        )
        .cornerRadius(20)
    }
}
