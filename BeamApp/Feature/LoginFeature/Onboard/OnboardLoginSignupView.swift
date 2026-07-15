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
    let loginStore: StoreOf<LoginFeature>
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
    @State private var showLogin = false
    @State private var codeDigits: [String] = Array(repeating: "", count: 6)
    @FocusState private var focusedField: Field?
    enum Field: Hashable { case name, email, password }

    var body: some View {
        WithViewStore(self.store, observe: \.self) { viewStore in
            let isSignupFormValid = !viewStore.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !viewStore.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !viewStore.password.isEmpty
            let canSubmitSignup = viewStore.isVerified &&
                isSignupFormValid &&
                !viewStore.isLoading &&
                privacyAgreement == .agree &&
                termsAgreement == .agree

            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color(red: 0.91, green: 0.74, blue: 0.72), Color(red: 0.67, green: 0.62, blue: 0.87)]),
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            Text("Join BEAM\nand start exploring")
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
                                        Text(idx == 1 ? "Sign Up" : idx == 2 ? "Select Artists & Songs" : "Done")
                                            .font(.caption)
                                            .foregroundColor(idx == 1 ? .blue : .white.opacity(0.7))
                                    }
                                    if idx < 3 {
                                        Rectangle()
                                            .fill(Color.white.opacity(0.4))
                                            .frame(width: 25, height: 2)
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 10)
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
                                CustomTextField("Name", text: viewStore.binding(
                                    get: \.username,
                                    send: SignupFeature.Action.usernameChanged
                                ))
                                .id(Field.name)
                                .focused($focusedField, equals: .name)
                                CustomTextField("Email Address", text: viewStore.binding(
                                    get: \.email,
                                    send: SignupFeature.Action.emailChanged
                                ), keyboardType: .emailAddress)
                                .id(Field.email)
                                .focused($focusedField, equals: .email)
                                HStack(spacing: 8) {
                                    Spacer(minLength: 0)
                                    Button("Verify") {
                                        if viewStore.errorMessage == "This email is already registered. A new verification code has been sent, so please check your email."
                                            || viewStore.errorMessage == "This email is already registered. Please go to the login screen."
                                            || viewStore.errorMessage == "This email is already verified." {
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
                                   errorMessage.contains("already registered") {
                                    Text(errorMessage)
                                        .foregroundColor(.red)
                                        .font(.caption)
                                        .padding(.top, 4)
                                }
                                if let errorMessage = viewStore.errorMessage,
                                   errorMessage == "There is a temporary issue with the email service.\nPlease try again later." {
                                    Text("Invalid email. Please check your email again.")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                        .padding(.top, 4)
                                }
                                CustomSecureField("Password", text: viewStore.binding(
                                    get: \.password,
                                    send: SignupFeature.Action.passwordChanged
                                ))
                                .id(Field.password)
                                .focused($focusedField, equals: .password)
                            }
                            .padding(.horizontal, 32)
                            .padding(.bottom, 8)

                            VStack(alignment: .leading, spacing: 8) {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 12) {
                                        Text("Privacy Consent")
                                            .foregroundColor(.white)
                                            .font(.subheadline)
                                        CheckBox(isChecked: privacyAgreement == .agree, label: "Agree") {
                                            privacyAgreement = .agree
                                        }
                                        CheckBox(isChecked: privacyAgreement == .disagree, label: "Disagree") {
                                            privacyAgreement = .disagree
                                        }
                                        Button("Details") { showPrivacySheet = true }
                                            .font(.caption)
                                            .foregroundColor(.purple)
                                    }
                                    HStack(spacing: 12) {
                                        Text("Terms Agreement")
                                            .foregroundColor(.white)
                                            .font(.subheadline)
                                        CheckBox(isChecked: termsAgreement == .agree, label: "Agree") {
                                            termsAgreement = .agree
                                        }
                                        CheckBox(isChecked: termsAgreement == .disagree, label: "Disagree") {
                                            termsAgreement = .disagree
                                        }
                                        Button("Details") { showTermsSheet = true }
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
                                guard canSubmitSignup else { return }
                                viewStore.send(.signupButtonTapped)
                            }) {
                                HStack {
                                    Spacer()
                                    Text("Done")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Image(systemName: "arrow.right")
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding()
                                .background(canSubmitSignup ? Color.purple : Color.gray.opacity(0.5))
                                .cornerRadius(12)
                            }
                            .disabled(!canSubmitSignup)
                            .padding(.horizontal, 32)
                            .padding(.top, 16)

                            Spacer()

                            HStack {
                                Text("Already have an account?")
                                    .foregroundColor(.white.opacity(0.7))
                                Button("Log In") {
                                    showLogin = true
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
            .sheet(isPresented: Binding(
                get: { showVerificationModal },
                set: { newValue in
                    showVerificationModal = newValue
                    if !newValue {
                        viewStore.send(.setVerificationModalPresented(false))
                    }
                }
            )) {
                VerificationCodeModal(
                    code: $codeDigits,
                    errorMessage: viewStore.errorMessage,
                    isLoading: viewStore.isLoading,
                    onClose: { showVerificationModal = false },
                    onVerify: {
                        let code = codeDigits.joined()
                        viewStore.send(.verificationCodeChanged(code))
                        viewStore.send(.verifyButtonTapped)
                    },
                    onResend: {
                        viewStore.send(.sendVerificationCodeButtonTapped)
                    }
                )
            }
            .onChange(of: viewStore.isVerificationModalPresented) { isPresented in
                showVerificationModal = isPresented
            }
            .onChange(of: viewStore.isSignupCompleted) { isSignupCompleted in
                guard isSignupCompleted, !didAutoAdvance else { return }
                didAutoAdvance = true
                onNext()
            }
            .onAppear {
                didAutoAdvance = false
                viewStore.send(.reset)
            }
            .onChange(of: viewStore.shouldShowLoginPrompt) { shouldShow in
                if shouldShow {
                    showLogin = true
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: { showLogin },
                set: { newValue in
                    showLogin = newValue
                    if !newValue {
                        viewStore.send(.setShouldShowLoginPrompt(false))
                    }
                }
            )) {
                LoginView(store: loginStore)
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
    var isLoading: Bool
    var onClose: () -> Void
    var onVerify: () -> Void
    var onResend: () -> Void
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
            Text("Email Verification Code")
                .font(.title2.bold())
                .padding(.top, 8)
            Image(systemName: "envelope.open")
                .resizable()
                .scaledToFit()
                .frame(height: 120)
                .padding(.vertical, 12)
            Text("Enter the verification code.")
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
                let displayMessage = errorMessage == "There is a temporary issue with the email service.\nPlease try again later." ? "The verification code does not match." : errorMessage
                Text(displayMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.top, 4)
            }
            VStack(spacing: 12) {
                Button(action: {
                    attempted = true
                    onVerify()
                }) {
                    Text("OK")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(code.joined().count == 6 ? Color.purple : Color.gray.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .contentShape(Rectangle())
                }
                .disabled(code.joined().count != 6 || isLoading)

                Button(action: onResend) {
                    Text(isLoading ? "Resending..." : "Resend Verification Code")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.purple)
                }
                .disabled(isLoading)
            }
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

private let privacyText = """
Privacy Policy

1. Purpose of Collecting and Using Personal Information
Beam Music (the app) does not collect or externally transmit users' personal information. The app may collect anonymous usage data only for service operation, feature improvement, and feedback.

2. Types of Information Collected
The app may collect information entered during sign-up, such as name, email, and phone number, as well as anonymous usage data generated while using the app, such as usage patterns and error logs. It does not collect information for advertising, paid content, in-app purchases, or other monetization.

3. Retention and Protection of Personal Information
Collected personal information and anonymous data are stored securely and are not externally transmitted or provided to third parties. The app uses reasonable security measures to protect personal information.

4. Use and Disposal of Personal Information
Collected personal information is used only to provide the service and improve features, and is deleted after the purpose of use has been fulfilled. Users may request deletion of their personal information at any time.

5. Policy Changes
If this privacy policy changes, users will be notified in advance through in-app notices or updates.
"""

private let termsText = """
Terms of Service
Service Overview
This application, Beam Music, is being developed by an individual or small team and is currently provided for testing and feedback collection.
Monetization
The app currently does not use advertising, paid content, in-app purchases, or other monetization, and no fees are charged to users.
Personal Information Handling
The app does not collect or externally transmit users' personal information. Anonymous usage data, such as usage patterns, may be collected to improve features.
Disclaimer
The app is under development, so some features may contain errors or usage limitations. The developer is not liable for issues arising from this, and use is subject to user consent.
Policy Changes
If service details or policies change, users will be notified in advance through in-app notices or updates.
"""
