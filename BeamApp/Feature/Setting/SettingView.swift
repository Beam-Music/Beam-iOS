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

            return ZStack {
                BeamScreenBackground()

                ScrollView {
                    VStack(spacing: AppTheme.Spacing.lg) {
                        BeamSectionHeader(
                            title: "Settings",
                            subtitle: "Profile and account",
                            actionTitle: nil,
                            action: nil
                        )

                        VStack(spacing: AppTheme.Spacing.md) {
                            Group {
                                if let url = profileImageUrl {
                                    AsyncImage(url: url) { image in
                                        image.resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        ProgressView()
                                            .tint(.white)
                                    }
                                } else {
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable()
                                        .foregroundColor(.white.opacity(0.72))
                                }
                            }
                            .frame(width: 112, height: 112)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.24), lineWidth: 2))
                            .shadow(color: Color.black.opacity(0.20), radius: 18, x: 0, y: 10)

                            if isEditingNickname {
                                VStack(spacing: AppTheme.Spacing.sm) {
                                    TextField("Enter a new nickname", text: $nickname)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .font(.body.weight(.medium))
                                        .foregroundColor(.white)
                                        .tint(.white)
                                        .frame(minHeight: 48)
                                        .padding(.horizontal, AppTheme.Spacing.md)
                                        .beamCard(cornerRadius: AppTheme.Radius.md, fillOpacity: 0.08)

                                    HStack(spacing: AppTheme.Spacing.sm) {
                                        Button("Cancel") {
                                            nickname = viewStore.userProfile?.username ?? ""
                                            isEditingNickname = false
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.white.opacity(0.72))

                                        Button(action: {
                                            Task {
                                                await updateNickname(viewStore: viewStore)
                                            }
                                        }) {
                                            if isSavingNickname {
                                                ProgressView()
                                                    .tint(.white)
                                            } else {
                                                Text("Save")
                                            }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(AppTheme.primaryAccent)
                                        .disabled(isSavingNickname)
                                    }
                                }
                            } else {
                                VStack(spacing: AppTheme.Spacing.xs) {
                                    Text(viewStore.userProfile?.username ?? "No nickname")
                                        .font(.title2.weight(.bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)

                                    Button {
                                        nickname = viewStore.userProfile?.username ?? ""
                                        isEditingNickname = true
                                    } label: {
                                        Label("Edit Nickname", systemImage: "pencil")
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.white.opacity(0.72))
                                }
                            }
                        }
                        .padding(AppTheme.Spacing.lg)
                        .frame(maxWidth: .infinity)
                        .beamCard(cornerRadius: AppTheme.Radius.lg, fillOpacity: 0.08)
                        .padding(.horizontal, AppTheme.Spacing.lg)

                        VStack(spacing: AppTheme.Spacing.xs) {
                            Button(action: {
                                isLoggedIn = false
                            }) {
                                Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                                    .frame(maxWidth: .infinity, minHeight: 48)
                            }
                            .buttonStyle(.bordered)
                            .tint(.white.opacity(0.74))

                            Button(role: .destructive, action: {
                                showDeleteAlert = true
                            }) {
                                Label("Delete Account", systemImage: "trash")
                                    .frame(maxWidth: .infinity, minHeight: 48)
                            }
                            .buttonStyle(.bordered)
                            .tint(AppTheme.destructive)
                        }
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.top, AppTheme.Spacing.xs)
                    }
                    .padding(.top, AppTheme.Spacing.lg)
                    .padding(.bottom, 120)
                    .alert(isPresented: $showDeleteAlert) {
                        Alert(
                            title: Text("Are you sure you want to delete your account?"),
                            message: Text("After deletion, your user data cannot be restored."),
                            primaryButton: .destructive(Text("OK")) {
                                guard let userId = UserDefaults.standard.string(forKey: "userID") else { return }
                                let url = URL(string: "\(Endpoints.baseURL)/api/users/\(userId)")!
                                var request = URLRequest(url: url)
                                request.httpMethod = "DELETE"
                                print("Account deletion request userID:", userId)
                                let token = viewStore.loginState.token
                                    ?? viewStore.signupState.token
                                    ?? TokenStorage.shared.fetchToken()
                                if let token {
                                    print("Account deletion request token:", token)
                                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                                } else {
                                    print("Account deletion request: no token")
                                }
                                URLSession.shared.dataTask(with: request) { data, response, error in
                                    if let error = error {
                                        print("Account deletion failed: \(error)")
                                        DispatchQueue.main.async {
                                            presentToast(message: "Failed to delete account")
                                        }
                                        return
                                    }
                                    if let httpResponse = response as? HTTPURLResponse {
                                        print("Account deletion response code: \(httpResponse.statusCode)")
                                        if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
                                            DispatchQueue.main.async {
                                                presentToast(message: "Account deletion completed")
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                                    UserDefaults.standard.removeObject(forKey: "userID")
                                                    isLoggedIn = false
                                                }
                                            }
                                        } else {
                                            print("Account deletion failed: server response error (status: \(httpResponse.statusCode))")
                                            DispatchQueue.main.async {
                                                presentToast(message: "Failed to delete account")
                                            }
                                        }
                                    }
                                }.resume()
                            },
                            secondaryButton: .cancel(Text("Cancel"))
                        )
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if showToast {
                    Text(toastMessage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .background(.ultraThinMaterial, in: Capsule())
                        .background(Color.black.opacity(0.28), in: Capsule())
                        .clipShape(Capsule())
                        .padding(.bottom, 120)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            store.send(.fetchUserProfile)
        }
        .alert("Failed to Edit Nickname", isPresented: $showNicknameError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(nicknameErrorMessage)
        }
        .animation(.easeInOut(duration: 0.2), value: showToast)
    }

    @MainActor
    private func updateNickname(viewStore: ViewStore<AppReducer.State, AppReducer.Action>) async {
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNickname.isEmpty else {
            nicknameErrorMessage = "Enter a nickname."
            showNicknameError = true
            return
        }

        guard let userId = UserDefaults.standard.string(forKey: "userID") else {
            nicknameErrorMessage = "Could not find user information."
            showNicknameError = true
            return
        }

        guard let token = viewStore.loginState.token ?? viewStore.signupState.token ?? TokenStorage.shared.fetchToken() else {
            nicknameErrorMessage = "Login token is missing."
            showNicknameError = true
            return
        }

        isSavingNickname = true
        defer { isSavingNickname = false }

        do {
            try await UserProfileClient.updateUsername(userId: userId, token: token, username: trimmedNickname)
            isEditingNickname = false
            store.send(.fetchUserProfile)
            presentToast(message: "Nickname saved.")
        } catch {
            nicknameErrorMessage = error.localizedDescription.isEmpty ? "Failed to edit nickname." : error.localizedDescription
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
