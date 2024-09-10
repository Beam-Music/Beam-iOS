//
//  File.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI
import SwiftData
import ComposableArchitecture

@main
struct Home: App {
    let store: StoreOf<AppReducer>
    
    init() {
        self.store = Store(initialState: AppReducer.State()) {
            AppReducer()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            RootView(store: store)
        }
        .modelContainer(for: Item.self)
    }
}

struct RootView: View {
    let store: StoreOf<AppReducer>
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            ZStack {
                if viewStore.databaseState == .idle {
                    TabBarView(store: store)
                } else {
                    MigrationView(store: store.scope(
                        state: \.migrationState,
                        action: AppReducer.Action.migration
                    ))
                }
            }
            .animation(.default, value: viewStore.databaseState)
        }
    }
}

struct MigrationView: View {
    let store: StoreOf<MigrationReducer>
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack {
                ProgressView()
                Text("Migrating database...")
            }
        }
    }
}

