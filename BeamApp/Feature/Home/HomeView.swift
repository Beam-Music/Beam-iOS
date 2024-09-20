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
        WithViewStore(self.store, observe: { $0 }) { viewStore in  // 상태 전체를 구독
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

                    Button(action: {
                        viewStore.send(.fetchListeningHistory)
                    }) {
                        Text("Fetch Listening History")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    if !viewStore.listeningHistory.isEmpty {
                        List(viewStore.listeningHistory, id: \.id) { item in
                            VStack(alignment: .leading) {
                                Text("Title: \(item.title)")
                                Text("Artist: \(item.artist)")
                                Text("Genre: \(item.genre)")
                                Text("Listened At: \(item.listenedAt)")
                                Text("Play Duration: \(item.playDuration) seconds")
                            }
                        }
                    }
                    
                    if let errorMessage = viewStore.errorMessage {
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .navigationTitle("Home")
                .onAppear {
                    viewStore.send(.fetchListeningHistory)  // 뷰가 나타날 때 리스닝 히스토리 가져오기
                }
            }
        }
    }
}


//struct HomeView_Previews: PreviewProvider {
//    static var previews: some View {
//        HomeView(isLoggedIn: .constant(true))
//    }
//}
