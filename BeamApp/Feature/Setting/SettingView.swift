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
        VStack {
            Button(action: {
                isLoggedIn = false
            }) {
                Text("Log out")
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            Spacer()
        }
    }
}

//struct SettingsView_Previews: PreviewProvider {
//    static var previews: some View {
//        SettingsView(isLoggedIn: true)
//    }
//}

