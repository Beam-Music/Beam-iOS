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
    @State private var privacyAgreement: Agreement = .none
    @State private var termsAgreement: Agreement = .none
    @State private var showPrivacySheet = false
    @State private var showTermsSheet = false
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
    @FocusState private var focusedField: Field?
    enum Field: Hashable { case name, email, password, phone }

    var body: some View {
        WithViewStore(self.store, observe: \.self) { viewStore in
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color(red: 0.91, green: 0.74, blue: 0.72), Color(red: 0.67, green: 0.62, blue: 0.87)]),
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollViewReader { proxy in
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
                                                store.send(.profileImageChanged(uiImage))
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
                                .id(Field.name)
                                .focused($focusedField, equals: .name)
                                CustomTextField("이메일 주소", text: viewStore.binding(
                                    get: \.email,
                                    send: SignupFeature.Action.emailChanged
                                ), keyboardType: .emailAddress)
                                .id(Field.email)
                                .focused($focusedField, equals: .email)
                                HStack(spacing: 8) {
                                    Spacer(minLength: 0)
                                    Button("인증하기") {
                                        if viewStore.errorMessage == "이미 가입된 이메일입니다. 새로운 인증 코드가 발송되었으니 이메일을 확인해주세요."
                                            || viewStore.errorMessage == "이미 가입된 이메일입니다. 로그인 화면으로 이동해주세요."
                                            || viewStore.errorMessage == "이미 인증된 이메일입니다." {
                                            return
                                        }
                                        viewStore.send(.sendVerificationCodeButtonTapped)
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 16)
                                    .background((viewStore.isVerified || viewStore.email.isEmpty || viewStore.isLoading) ? Color.gray.opacity(0.5) : Color.purple)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                    .disabled(viewStore.isVerified || viewStore.email.isEmpty || viewStore.isLoading)
                                }
                                if let errorMessage = viewStore.errorMessage,
                                   errorMessage.contains("이미 가입된 이메일") {
                                    Text(errorMessage)
                                        .foregroundColor(.red)
                                        .font(.caption)
                                        .padding(.top, 4)
                                }
                                if let errorMessage = viewStore.errorMessage,
                                   errorMessage == "이메일 서비스에 일시적인 문제가 있습니다.\n잠시 후 다시 시도해주세요." {
                                    Text("유효하지 않은 이메일입니다. 이메일을 다시 확인해주세요.")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                        .padding(.top, 4)
                                }
                                CustomSecureField("비밀번호", text: viewStore.binding(
                                    get: \.password,
                                    send: SignupFeature.Action.passwordChanged
                                ))
                                .id(Field.password)
                                .focused($focusedField, equals: .password)
                                CustomTextField("전화번호", text: viewStore.binding(
                                    get: \.phone,
                                    send: SignupFeature.Action.phoneChanged
                                ), keyboardType: .phonePad)
                                .id(Field.phone)
                                .focused($focusedField, equals: .phone)
                            }
                            .padding(.horizontal, 32)
                            .padding(.bottom, 8)

                            VStack(alignment: .leading, spacing: 8) {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 12) {
                                        Text("프라이버시 동의")
                                            .foregroundColor(.white)
                                            .font(.subheadline)
                                        CheckBox(isChecked: privacyAgreement == .agree, label: "동의") {
                                            privacyAgreement = .agree
                                        }
                                        CheckBox(isChecked: privacyAgreement == .disagree, label: "비동의") {
                                            privacyAgreement = .disagree
                                        }
                                        Button("자세히") { showPrivacySheet = true }
                                            .font(.caption)
                                            .foregroundColor(.purple)
                                    }
                                    HStack(spacing: 12) {
                                        Text("이용약관 동의")
                                            .foregroundColor(.white)
                                            .font(.subheadline)
                                        CheckBox(isChecked: termsAgreement == .agree, label: "동의") {
                                            termsAgreement = .agree
                                        }
                                        CheckBox(isChecked: termsAgreement == .disagree, label: "비동의") {
                                            termsAgreement = .disagree
                                        }
                                        Button("자세히") { showTermsSheet = true }
                                            .font(.caption)
                                            .foregroundColor(.purple)
                                    }
                                }
                            }
                            .padding(.horizontal, 32)
                            .padding(.vertical, 8)
                            .sheet(isPresented: $showPrivacySheet) {
                                ScrollView { Text(privacyText).padding() }
                            }
                            .sheet(isPresented: $showTermsSheet) {
                                ScrollView { Text(termsText).padding() }
                            }

                            Button(action: {
                                viewStore.send(.signupButtonTapped)
                                if viewStore.isVerified {
                                    if let token = viewStore.token {
                                        Task {
                                            try? await TokenStorage.shared.saveToken(token)
                                            onNext()
                                        }
                                    } else {
                                        onNext()
                                    }
                                }
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
                                .background((viewStore.verificationCode.count == 6 && privacyAgreement == .agree && termsAgreement == .agree && !viewStore.isLoading) ? Color.purple : Color.gray.opacity(0.5))
                                .cornerRadius(12)
                            }
                            .disabled(viewStore.verificationCode.count != 6 || viewStore.isLoading || privacyAgreement != .agree || termsAgreement != .agree)
                            .padding(.horizontal, 32)
                            .padding(.top, 16)

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
                        .frame(minHeight: UIScreen.main.bounds.height)
                        .padding()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        .onChange(of: focusedField) { newValue in
                            if let field = newValue {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    withAnimation {
                                        proxy.scrollTo(field, anchor: .center)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showVerificationModal, onDismiss: {
                if let errorMessage = viewStore.errorMessage, errorMessage.contains("이미 가입된 이메일") {
                    // errorMessage를 nil로 리셋하는 액션이 있다면 아래처럼 사용
                    // viewStore.send(.resetErrorMessage)
                    // 없으면 아래처럼 직접 리셋 (Binding이 아니므로 State로 관리 필요)
                }
            }) {
                VerificationCodeModal(
                    code: $codeDigits,
                    errorMessage: viewStore.errorMessage,
                    onClose: { showVerificationModal = false },
                    onVerify: {
                        let code = codeDigits.joined()
                        viewStore.send(.verificationCodeChanged(code))
                        viewStore.send(.verifyButtonTapped)
                        // showVerificationModal = false  // 인증 성공 시에만 닫히도록 변경
                    }
                )
            }
            .onChange(of: viewStore.errorMessage) { newValue in
                if newValue == "인증 메일이 발송되었습니다. 이메일을 확인해주세요." ||
                   newValue == "이미 가입된 이메일입니다. 새로운 인증 코드가 발송되었으니 이메일을 확인해주세요." {
                    showVerificationModal = true
                } else if newValue == "이미 가입된 이메일입니다. 로그인 화면으로 이동해주세요." ||
                          newValue == "이미 인증된 이메일입니다." {
                    showVerificationModal = false
                }
            }
            .onChange(of: viewStore.isVerified) { isVerified in
                if isVerified {
                    showVerificationModal = false
                }
            }
            .onAppear {
                viewStore.send(.reset)
            }
        }
    }
}

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

struct VerificationCodeModal: View {
    @Binding var code: [String]
    var errorMessage: String?
    var onClose: () -> Void
    var onVerify: () -> Void
    @FocusState private var focusedIndex: Int?
    @State private var attempted: Bool = false

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
            Text("verification code를 입력해주세요.")
                .foregroundColor(.gray)
                .padding(.bottom, 16)
            HStack(spacing: 12) {
                ForEach(0..<6) { idx in
                    TextField("", text: Binding(
                        get: { code[idx] },
                        set: { newValue in
                            let old = code[idx]
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered.count > 1 {
                                code[idx] = String(filtered.prefix(1))
                            } else {
                                code[idx] = filtered
                            }
                            if !filtered.isEmpty && idx < 5 {
                                focusedIndex = idx + 1
                            }
                            if filtered.isEmpty && old != "" && code.allSatisfy({ $0.isEmpty }) == false {
                                for i in 0..<code.count {
                                    code[i] = ""
                                }
                                focusedIndex = 0
                            }
                            if filtered.isEmpty && old != "" && idx > 0 {
                                focusedIndex = idx - 1
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
            .onAppear { focusedIndex = 0 }
            if attempted, let errorMessage = errorMessage, !errorMessage.isEmpty {
                let displayMessage = errorMessage == "이메일 서비스에 일시적인 문제가 있습니다.\n잠시 후 다시 시도해주세요." ? "인증 번호가 일치하지 않습니다." : errorMessage
                Text(displayMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.top, 4)
            }
            Button(action: {
                attempted = true
                onVerify()
            }) {
                Text("확인")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(code.joined().count == 6 ? Color.purple : Color.gray.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .contentShape(Rectangle())
            }
            .padding(.horizontal, 32)
            .disabled(code.joined().count != 6)
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

private let privacyText = """
📄  프라이버시 약관

1. 개인정보의 수집 및 이용 목적
Beam Music(이하 '본 앱')은 사용자의 개인정보를 수집하거나 외부로 전송하지 않습니다. 본 앱은 오직 서비스 제공 및 기능 개선, 피드백 수집을 목적으로만 사용자의 익명 데이터를 수집할 수 있습니다.

2. 수집하는 정보의 종류
본 앱은 사용자의 이름, 이메일, 전화번호 등 회원가입 시 입력한 정보와, 앱 사용 과정에서 생성되는 익명 사용 데이터(예: 사용 패턴, 오류 로그 등)를 수집할 수 있습니다. 단, 광고, 유료 콘텐츠, 인앱 결제 등 수익 창출을 위한 정보는 수집하지 않습니다.

3. 개인정보의 보관 및 보호
수집된 개인정보 및 익명 데이터는 안전하게 저장되며, 외부로 전송되거나 제3자에게 제공되지 않습니다. 본 앱은 개인정보 보호를 위해 합리적인 보안 조치를 취하고 있습니다.

4. 개인정보의 이용 및 파기
수집된 개인정보는 서비스 제공 및 기능 개선을 위해서만 사용되며, 이용 목적이 달성된 후에는 즉시 파기됩니다. 사용자는 언제든지 개인정보 삭제를 요청할 수 있습니다.

5. 약관 변경
프라이버시 약관의 내용이 변경될 경우, 앱 내 공지 또는 업데이트를 통해 사전 안내드립니다.
"""

private let termsText = """
📄  이용약관 
서비스 개요
본 애플리케이션(이하 'Beam Music')은 개인 또는 소규모 팀이 개발 중인 앱으로, 현재는 테스트 및 피드백 수집을 목적으로 제공됩니다.
수익 창출
본 앱은 현재 광고, 유료 콘텐츠, 인앱 결제 등 수익을 목적으로 하지 않으며, 어떠한 비용도 이용자에게 청구되지 않습니다.
개인정보 처리
본 앱은 사용자의 개인정보를 수집하거나 외부로 전송하지 않습니다. 단, 기능 개선을 위한 익명 사용 데이터(예: 사용 패턴)는 수집될 수 있습니다.
면책 조항
본 앱은 개발 중으로, 일부 기능의 오류나 사용 제한이 발생할 수 있습니다. 이에 따른 책임은 개발자가 지지 않으며, 사용자 동의 하에 사용됩니다.
약관 변경
서비스 내용이나 정책 변경 시, 앱 내 공지 또는 업데이트를 통해 사전 안내드립니다.
"""
