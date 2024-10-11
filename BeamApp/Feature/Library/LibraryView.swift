//
//  LibraryView.swift
//  BeamApp
//
//  Created by freed on 10/10/24.
//

import SwiftUI
import ComposableArchitecture

struct LibraryView: View {
    let store: StoreOf<LibraryReducer>
    @Binding var isMiniPlayerVisible: Bool

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            VStack(spacing: 20) {
                if let errorMessage = viewStore.errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                } else {
                    List(viewStore.playlists) { playlist in
                        HStack {
                            Text(playlist.name)
                            Spacer()
                            Button(action: {
                                viewStore.send(.selectPlaylist(playlist))
                                isMiniPlayerVisible = true
                            }) {
                                Text("Select")
                            }
                        }
                        .padding()
                    }
                }
            }
            .onAppear {
                viewStore.send(.fetchUserPlaylists)
            }
            .onChange(of: viewStore.playlist) { _ in
                isMiniPlayerVisible = !viewStore.playlist.isEmpty
            }
        }
    }
}
