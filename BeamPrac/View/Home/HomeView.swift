//
//  HomeView.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI

struct HomeView: View {
    @Binding var isLoggedIn: Bool

    var body: some View {
            NavigationView {
                VStack(spacing: 20) {
                    Text("Welcome to Home View")
                        .font(.title)
                    
                    Text("You are now logged in!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        // 로그아웃 액션
                        isLoggedIn = false
                    }) {
                        Text("Log out")
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .navigationTitle("Home")
            }
        }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(isLoggedIn: .constant(true))
    }
}
