//
//  BeamPracApp.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI
import ComposableArchitecture
import SwiftData

@main
struct BeamPracApp: App {
    let container = try! ModelContainer(for: TokenEntity.self)

    let store: StoreOf<AppReducer> = Store(initialState: AppReducer.State()) {
           AppReducer()
               ._printChanges()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView(store: store)
              .modelContainer(container)  
        }
    }
}
