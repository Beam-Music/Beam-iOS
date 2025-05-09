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

                Text("오늘 하루,\n네 마음 한구석을 살짝\n채워줄 무언가가 있다면\n좋을 텐데.")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 24)

                Spacer()

                HStack {
                    Spacer()
                    Button("다음 →", action: onFinish)
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
