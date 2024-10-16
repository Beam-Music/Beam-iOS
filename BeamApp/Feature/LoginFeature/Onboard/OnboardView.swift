//
//  OnboardView.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI
import ComposableArchitecture

struct OnboardView: View {
    let loginStore: StoreOf<LoginFeature>
    let signupStore: StoreOf<SignupFeature>
    @State private var navigateToLogin: Bool = false
    @State private var navigateToSignup: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Image("background_image")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .edgesIgnoringSafeArea(.all)
                VStack {
                    HStack {
                        Spacer()
                    }
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "music.note")
                            .font(.system(size: 40))
                            .foregroundColor(.purple)
                            .padding(.bottom, 20)
                        
                        Text("Millions of Songs.\nFree on BeamApp")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 10)
                        
                        Text("Discover new music and enjoy your favorite songs.")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 40)
                        
                        NavigationLink(
                            destination: SignupView(store: signupStore),
                            isActive: $navigateToSignup
                        ) {
                            Button(action: {
                                navigateToSignup = true
                            }) {
                                
                                Text("Sign up free")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.purple)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                    .padding(.horizontal, 40)
                            }
                        }
                        .padding(.bottom, 15)
                        
                        NavigationLink(
                            destination: LoginView(store: loginStore),
                            isActive: $navigateToLogin
                        ) {
                            Button(action: {
                                navigateToLogin = true
                            }) {
                                Text("Log in")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .foregroundColor(.purple)
                                    .cornerRadius(10)
                                    .padding(.horizontal, 40)
                            }
                        }
                    }
                    .padding(.bottom, 60)
                    Spacer()
                }
                .padding()
            }
        }
    }
}
