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
    @Binding var isMiniPlayerVisible: Bool
    let store: StoreOf<HomeReducer>
    
    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            NavigationView {
                VStack(spacing: 20) {
//                    Button(action: {
//                        isLoggedIn = false
//                    }) {
//                        Text("Log out")
//                            .padding()
//                            .background(Color.red)
//                            .foregroundColor(.white)
//                            .cornerRadius(10)
//                    }
                    List(viewStore.recommendedPlaylists, id: \.id) { playlist in
                        HStack {
                            Text(playlist.name)
                            Spacer()
                            Button(action: {
                                viewStore.send(.selectPlaylist(playlist))
                                isMiniPlayerVisible = true
                            }) {
                                
                            }
                        }
                        .padding()
                    }
                }
                .padding()
                .onAppear {
                    viewStore.send(.fetchUserPlaylists)  
                    viewStore.send(.fetchRecommendPlaylists)
                    if let selectedPlaylistID = viewStore.selectedPlaylistID {
                        viewStore.send(.fetchPlaylist(selectedPlaylistID))
                        viewStore.send(.fetchRecommendPlaylistSongs(selectedPlaylistID))
                    } else {
                        print("No selected playlist ID")
                    }
                }
                .onChange(of: viewStore.playlist) { _ in
                    isMiniPlayerVisible = !viewStore.playlist.isEmpty
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
