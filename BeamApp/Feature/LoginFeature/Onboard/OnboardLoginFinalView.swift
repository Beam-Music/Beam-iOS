//
//  OnboardFinalView2.swift
//  BeamApp
//
//  Created by anonymous on 5/7/25.
//

import SwiftUI

struct OnboardFinalView: View {
    let onFinish: () -> Void

    var body: some View {
        ZStack {
            Image("onboard_final")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack {
                Spacer().frame(height: 80)

                Text("If only there were something\nto gently fill a corner\nof your heart today.")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 24)

                Spacer()

                HStack {
                    Spacer()
                    Button("Next →", action: onFinish)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.trailing, 32)
                }
                Spacer().frame(height: 40)
            }
        }
        .ignoresSafeArea(edges: .top)
    }
}

struct OnboardFinalView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardFinalView(onFinish: { print("Finished") })
    }
}
