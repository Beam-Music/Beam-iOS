//
//  MiniPlayerView.swift
//  BeamApp
//
//  Created by freed on 10/11/24.
//
import SwiftUI
import ComposableArchitecture

struct MiniPlayerView: View {
    let store: StoreOf<PlayerReducer>
    @State private var isMiniPlayerVisible: Bool = true
    @Binding var isPlayerViewVisible: Bool
    
    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            VStack {
                HStack {
                    Image(systemName: "music.note")
                        .frame(width: 40, height: 40)
                    
                    Spacer()
                    
                    Button(action: {
                        isMiniPlayerVisible = false
                    }) {
                        Image(systemName: "arrow.up")
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.3))
                .onTapGesture {
                    isPlayerViewVisible = true
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(Color.black.opacity(0.8))
        }
    }
}

