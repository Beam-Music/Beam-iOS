//
//  BackButton.swift
//  BeamApp
//
//  Created by freed on 10/24/24.
//

import SwiftUI

struct BackButton: View {
    var action: () -> Void 
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "chevron.left")
                    .aspectRatio(contentMode: .fit)
                Text("뒤로")
                    .foregroundColor(.white)
            }
        }
        .foregroundColor(.white)
    }
}

