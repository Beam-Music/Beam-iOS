//
//  CustomNavigationBar.swift
//  BeamPrac
//
//  Created by freed on 9/10/24.
//

import SwiftUI

struct CustomNavigationBar<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .padding()
            content
        }
    }
}

