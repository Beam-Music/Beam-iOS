//
//  PrimaryButton.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .foregroundColor(.white)
                .padding()
                .background(Color.primaryColor)
                .cornerRadius(8)
        }
    }
}
