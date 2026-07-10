//
//  SettingView.swift
//  BeamApp
//
//  Created by freed on 10/14/24.
//

import SwiftUI
import ComposableArchitecture

struct SettingsView: View {
    let store: StoreOf<AppReducer>
    @Binding var isLoggedIn: Bool
    @State private var showDeleteAlert = false
    @State private var isEditingNickname = false
    @State private var nickname = ""
    @State private var isSavingNickname = false
    @State private var nicknameErrorMessage = ""
    @State private var showNicknameError = false
    @State private var toastMessage = ""
    @State private var showToast = false
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            let urlString = viewStore.userProfile?.profileImageUrl
            let fullUrlString: String? = {
                guard let urlString else { return nil }
                if urlString.hasPrefix("http") {
                    return urlString
                } else {
                    return Endpoints.baseURL + urlString
                }
            }()
            let profileImageUrl = fullUrlString.flatMap { URL(string: $0) }
            print("[프로필 이미지 로딩 URL]", profileImageUrl?.absoluteString ?? "nil")
            print("userProfile: \(String(describing: viewStore.userProfile))")
            print("profileImageUrl(raw): \(String(describing: viewStore.userProfile?.profileImageUrl))")
            print("profileImageUrl(final): \(profileImageUrl?.absoluteString ?? "nil")")

            return ZStack {
                AppTheme.mainGradient
                .ignoresSafeArea()
                VStack {
                    if let url = profileImageUrl {
                        AsyncImage(url: url) { image in
                            image.resizable()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 3))
                        .padding(.top, 40)
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 120, height: 120)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.top, 40)
                    }
                    if isEditingNickname {
                        VStack(spacing: 10) {
                            TextField("새 닉네임을 입력해 주세요", text: $nickname)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.system(size: 16, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.white.opacity(0.14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                )
                                .foregroundColor(.white)
                                .tint(.white)

                            HStack(spacing: 10) {
                                Button("취소") {
                                    nickname = viewStore.userProfile?.username ?? ""
                                    isEditingNickname = false
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())

                                Button(action: {
                                    Task {
                                        await updateNickname(viewStore: viewStore)
                                    }
                                }) {
                                    if isSavingNickname {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text("저장")
                                    }
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.18))
                                .clipShape(Capsule())
                                .disabled(isSavingNickname)
                            }
                        }
                        .padding(.top, 12)
                        .padding(.horizontal, 24)
                    } else {
                        Text(viewStore.userProfile?.username ?? "닉네임 없음")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .padding(.top, 12)

                        Button("닉네임 수정") {
                            nickname = viewStore.userProfile?.username ?? ""
                            isEditingNickname = true
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.14))
                        .clipShape(Capsule())
                        .padding(.top, 8)
                    }

                    Spacer()

                    VStack(spacing: 10) {
                        Button(action: {
                            isLoggedIn = false
                        }) {
                            Text("Log out")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.10))
                                .foregroundColor(.white.opacity(0.92))
                                .clipShape(Capsule())
                        }
                        Button(action: {
                            showDeleteAlert = true
                        }) {
                            Text("회원 탈퇴")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.08))
                                .foregroundColor(.white.opacity(0.82))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.bottom, 36)
                    .alert(isPresented: $showDeleteAlert) {
                        Alert(
                            title: Text("정말 탈퇴하시겠습니까?"),
                            message: Text("탈퇴 후에는 유저 데이터를 되돌릴 수 없습니다."),
                            primaryButton: .destructive(Text("확인")) {
                                guard let userId = UserDefaults.standard.string(forKey: "userID") else { return }
                                let url = URL(string: "\(Endpoints.baseURL)/api/users/\(userId)")!
                                var request = URLRequest(url: url)
                                request.httpMethod = "DELETE"
                                print("회원 탈퇴 요청 userID:", userId)
                                let token = viewStore.loginState.token
                                    ?? viewStore.signupState.token
                                    ?? TokenStorage.shared.fetchToken()
                                if let token {
                                    print("회원 탈퇴 요청 토큰:", token)
                                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                                } else {
                                    print("회원 탈퇴 요청: 토큰 없음")
                                }
                                URLSession.shared.dataTask(with: request) { data, response, error in
                                    if let error = error {
                                        print("회원 탈퇴 실패: \(error)")
                                        DispatchQueue.main.async {
                                            presentToast(message: "회원 탈퇴에 실패했어요")
                                        }
                                        return
                                    }
                                    if let httpResponse = response as? HTTPURLResponse {
                                        print("회원 탈퇴 응답 코드: \(httpResponse.statusCode)")
                                        if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
                                            DispatchQueue.main.async {
                                                presentToast(message: "회원 탈퇴가 완료되었어요")
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                                    UserDefaults.standard.removeObject(forKey: "userID")
                                                    isLoggedIn = false
                                                }
                                            }
                                        } else {
                                            print("회원 탈퇴 실패: 서버 응답 오류 (status: \(httpResponse.statusCode))")
                                            DispatchQueue.main.async {
                                                presentToast(message: "회원 탈퇴에 실패했어요")
                                            }
                                        }
                                    }
                                }.resume()
                            },
                            secondaryButton: .cancel(Text("취소"))
                        )
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if showToast {
                    Text(toastMessage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.28))
                        .clipShape(Capsule())
                        .padding(.bottom, 120)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            store.send(.fetchUserProfile)
        }
        .alert("닉네임 수정 실패", isPresented: $showNicknameError) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(nicknameErrorMessage)
        }
        .animation(.easeInOut(duration: 0.2), value: showToast)
    }

    @MainActor
    private func updateNickname(viewStore: ViewStore<AppReducer.State, AppReducer.Action>) async {
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNickname.isEmpty else {
            nicknameErrorMessage = "닉네임을 입력해 주세요."
            showNicknameError = true
            return
        }

        guard let userId = UserDefaults.standard.string(forKey: "userID") else {
            nicknameErrorMessage = "사용자 정보를 찾을 수 없습니다."
            showNicknameError = true
            return
        }

        guard let token = viewStore.loginState.token ?? viewStore.signupState.token ?? TokenStorage.shared.fetchToken() else {
            nicknameErrorMessage = "로그인 토큰이 없습니다."
            showNicknameError = true
            return
        }

        isSavingNickname = true
        defer { isSavingNickname = false }

        do {
            try await UserProfileClient.updateUsername(userId: userId, token: token, username: trimmedNickname)
            isEditingNickname = false
            store.send(.fetchUserProfile)
            presentToast(message: "닉네임이 저장되었어요")
        } catch {
            nicknameErrorMessage = error.localizedDescription.isEmpty ? "닉네임 수정에 실패했습니다." : error.localizedDescription
            showNicknameError = true
        }
    }

    @MainActor
    private func presentToast(message: String) {
        toastMessage = message
        showToast = true

        Task {
            try? await Task.sleep(for: .seconds(1.6))
            await MainActor.run {
                showToast = false
            }
        }
    }
}

//struct SettingsView_Previews: PreviewProvider {
//    static var previews: some View {
//        SettingsView(isLoggedIn: true)
//    }
//}

