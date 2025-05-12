//
//  LibraryView.swift
//  BeamApp
//
//  Created by freed on 10/10/24.
//

import SwiftUI
import ComposableArchitecture

// 별 데이터 모델, StarFieldView, ScrollOffsetPreferenceKey가 HomeView.swift에 있다면 import해서 사용하거나, 중복 정의를 피하세요.
// 여기서는 예시로 별 관련 코드가 이미 프로젝트에 있다고 가정합니다.

struct LibraryView: View {
    let store: StoreOf<LibraryReducer>
    @Binding var isMiniPlayerVisible: Bool
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.purple.opacity(0.7), Color.pink.opacity(0.5)]),
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            StarFieldView(starCount: 40, scrollOffset: scrollOffset)
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
                                }) {}
                            }
                            .padding()
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .global).minY)
                            }
                        )
                        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                            scrollOffset = value
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
}
