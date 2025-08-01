 //
//  BeamPracApp.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//
// BeamApp.swift

import SwiftUI
import ComposableArchitecture
import SwiftData
import AVFoundation

@main
struct BeamApp: App {
    let container: ModelContainer
    let store: StoreOf<AppReducer>

    init() {
        do {
            container = try ModelContainer(for: TokenEntity.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        
        store = Store(initialState: AppReducer.State()) {
            AppReducer()
                ._printChanges()
        }

        // do {
        //     try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        //     try AVAudioSession.sharedInstance().setActive(true)
        // } catch {
        //     print("❌ Failed to set up audio session: \(error)")
        // }
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .modelContainer(container)
        }
    }
}
