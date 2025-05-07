//
//  SettingView.swift
//  BeamApp
//
//  Created by freed on 10/14/24.
//

import SwiftUI
import ComposableArchitecture

struct SettingsView: View {
    @Binding var isLoggedIn: Bool
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.purple.opacity(0.7), Color.pink.opacity(0.5)]),
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            VStack {
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
}

//struct SettingsView_Previews: PreviewProvider {
//    static var previews: some View {
//        SettingsView(isLoggedIn: true)
//    }
//}

