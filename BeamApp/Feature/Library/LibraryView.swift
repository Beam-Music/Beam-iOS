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

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            VStack(spacing: 20) {
                Text("재생 목록")
                    .font(.largeTitle)
                    .padding()

                if let errorMessage = viewStore.errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                } else {
                    List(viewStore.playlists) { playlist in
                        HStack {
                            Text(playlist.name)
                            Spacer()
                        }
                        .padding()
                    }
                }
            }
            .onAppear {
                viewStore.send(.fetchUserPlaylists)
            }
        }
    }
}
