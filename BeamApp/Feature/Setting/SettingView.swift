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
            print("userProfile: \(String(describing: viewStore.userProfile))")
            print("profileImageUrl(raw): \(String(describing: viewStore.userProfile?.profileImageUrl))")
            print("profileImageUrl(final): \(profileImageUrl?.absoluteString ?? "nil")")

            return ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.purple.opacity(0.7), Color.pink.opacity(0.5)]),
                    startPoint: .top, endPoint: .bottom
                )
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
                    Button(action: {
                        isLoggedIn = false
                    }) {
                        Text("Log out")
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.primaryBackground)
                            .cornerRadius(10)
                    }
                    Button(action: {
                        showDeleteAlert = true
                    }) {
                        Text("회원 탈퇴")
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
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
                                        return
                                    }
                                    if let httpResponse = response as? HTTPURLResponse {
                                        print("회원 탈퇴 응답 코드: \(httpResponse.statusCode)")
                                        if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
                                            DispatchQueue.main.async {
                                                UserDefaults.standard.removeObject(forKey: "userID")
                                                isLoggedIn = false
                                            }
                                        } else {
                                            print("회원 탈퇴 실패: 서버 응답 오류 (status: \(httpResponse.statusCode))")
                                        }
                                    }
                                }.resume()
                            },
                            secondaryButton: .cancel(Text("취소"))
                        )
                    }
                    Spacer()
                }
            }
        }
        .onAppear {
            store.send(.fetchUserProfile)
        }
    }
}

//struct SettingsView_Previews: PreviewProvider {
//    static var previews: some View {
//        SettingsView(isLoggedIn: true)
//    }
//}

