//
//  AppState.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI

class AppState: ObservableObject {
    @Published var databaseState: DatabaseState = .migrating
    @Published var isLoggedIn: Bool = false
    @Published var username: String = ""
    @Published var tabSelection: TabSelection = .player
    
    func login(username: String, password: String) -> Bool {
        // 여기에 실제 로그인 로직을 구현합니다.
        // 지금은 간단한 예시로 구현합니다.
        if username == "user" && password == "password" {
            self.isLoggedIn = true
            self.username = username
            return true
        }
        return false
    }
    
    func logout() {
        isLoggedIn = false
        username = ""
    }
    
    func completeMigration() {
        databaseState = .idle
    }
}

enum DatabaseState: Equatable {
    case idle, migrating, error
}

enum TabSelection: Equatable {
    case home, player, generator
}
