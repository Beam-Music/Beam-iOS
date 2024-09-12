//
//  MigrationVIew.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI

struct MigrationView: View {
    @Binding var databaseState: DatabaseState
    @State private var progress: Double = 0.0
    
    var body: some View {
        VStack {
            ProgressView("Migrating database...", value: progress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle())
                .padding()
            
            Text(String(format: "Progress: %.0f%%", progress * 100))
                .padding()
            
            // 시뮬레이션을 위한 임시 버튼
            Button("Simulate Migration") {
                simulateMigration()
            }
            .padding()
            .disabled(progress > 0 && progress < 1)
        }
    }
    
    private func simulateMigration() {
        progress = 0.0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if progress < 1.0 {
                progress += 0.1
            } else {
                timer.invalidate()
                databaseState = .idle
            }
        }
        timer.fire()
    }
}

struct MigrationView_Previews: PreviewProvider {
    static var previews: some View {
        MigrationView(databaseState: .constant(.migrating))
    }
}
