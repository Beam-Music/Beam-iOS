//
//  HomeView.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI
import ComposableArchitecture

struct HomeView: View {
    @Binding var isLoggedIn: Bool
    let store: StoreOf<HomeReducer>
    
    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            NavigationView {
                VStack(spacing: 20) {
                    Button(action: {
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
                .onAppear {
                    viewStore.send(.fetchUserPlaylists)  
                    if let selectedPlaylistID = viewStore.selectedPlaylistID {
                        viewStore.send(.fetchPlaylist(selectedPlaylistID))
                    } else {
                        print("No selected playlist ID")
                    }
                }
            }
            .padding()
        }
    }
}


//struct HomeView_Previews: PreviewProvider {
//    static var previews: some View {
//        HomeView(isLoggedIn: .constant(true))
//    }
//}
