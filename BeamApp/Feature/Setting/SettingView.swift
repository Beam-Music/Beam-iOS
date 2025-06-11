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

