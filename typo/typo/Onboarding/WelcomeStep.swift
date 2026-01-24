//
//  WelcomeStep.swift
//  typo
//

import SwiftUI

struct WelcomeStep: View {
    var onNext: () -> Void

    var body: some View {
        ZStack {
            // Gradient background like TypoTap
            LinearGradient(
                colors: [
                    Color(hex: "1E88E5"),
                    Color(hex: "42A5F5"),
                    Color(hex: "4DD0E1")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Main title - bold, white, centered
                VStack(spacing: 6) {
                    Text("Meet your")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("new writing assistant")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                Spacer()

                // Get Started button - glassmorphism style
                Button(action: onNext) {
                    Text("Get Started")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.white.opacity(0.25))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)

                Spacer()
                    .frame(height: 60)
            }
        }
    }
}
