//
//  LoginView.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI
import ComposableArchitecture

struct LoginView: View {
    let store: StoreOf<LoginFeature>
    
    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            VStack {
                TextField("Username", text: viewStore.binding(
                    get: \.username,
                    send: LoginFeature.Action.usernameChanged
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                
                SecureField("Password", text: viewStore.binding(
                    get: \.password,
                    send: LoginFeature.Action.passwordChanged
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Login") {
                    viewStore.send(.loginButtonTapped)
                }
                .disabled(viewStore.isLoading)
                
                if viewStore.isLoading {
                    ProgressView()
                }
                
                if let errorMessage = viewStore.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
            .padding()
        }
    }
}

//struct LoginView_Previews: PreviewProvider {
//    static var previews: some View {
//        LoginView()
//    }
//}
