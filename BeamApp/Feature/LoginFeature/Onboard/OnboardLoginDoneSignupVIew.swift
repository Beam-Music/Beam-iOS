//
//  OnboardLoginDoneSignupVIew.swift
//  BeamApp
//
//  Created by anonymous on 5/23/25.
//

import SwiftUI

struct OnboardLoginDoneSignupView: View {
    let onNext: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Top title
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome aboard!")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Your personal music journey\nstarts now. 🎧")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding(.top, 80)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Three-step progress bar
                HStack(spacing: 0) {
                    ForEach(1...3, id: \.self) { idx in
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(idx == 3 ? Color.purple : Color.white.opacity(0.4))
                                    .frame(width: 32, height: 32)
                                Text("\(idx)")
                                    .foregroundColor(idx == 3 ? .white : .purple)
                                    .fontWeight(.bold)
                            }
                            Text(idx == 1 ? "Sign Up" : idx == 2 ? "Select Artists & Songs" : "Done")
                                .font(.caption)
                                .foregroundColor(idx == 3 ? .purple : .white.opacity(0.7))
                        }
                        if idx < 3 {
                            Rectangle()
                                .fill(idx == 3 ? Color.purple : Color.white.opacity(0.4))
                                .frame(width: 25, height: 2)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 24)

                // Image
                Image("signupdone")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 315, height: 478)
                    .clipped()
                    .cornerRadius(32)
                    .padding(.top, 16)

                Spacer()
            }
            // Start button
            Button(action: onNext) {
                HStack {
                    Spacer()
                    Text("Get Started")
                        .font(.headline)
                        .foregroundColor(.white)
                    Image(systemName: "arrow.right")
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding()
                .background(Color.purple)
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.91, green: 0.74, blue: 0.72), Color(red: 0.67, green: 0.62, blue: 0.87)]),
                startPoint: .top, endPoint: .bottom
            )
        )
        .ignoresSafeArea()
    }
}

struct OnboardLoginDoneSignupView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardLoginDoneSignupView(onNext: {})
    }
}
