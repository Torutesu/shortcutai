//
//  FeaturesStep.swift
//  typo
//

import SwiftUI
import AVKit

struct FeaturesStep: View {
    var onNext: () -> Void
    var onBack: () -> Void

    @State private var player: AVPlayer?
    @State private var showKeys = false
    @State private var keyStates: [Bool] = [false, false, false] // ⌘, ⇧, T

    private let keys = ["⌘", "⇧", "T"]

    var body: some View {
        ZStack {
            // White background
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 30)

                Text("How to open TexTab")
                    .font(.custom("Nunito-Black", size: 32))
                    .foregroundColor(.black)

                Spacer()
                    .frame(height: 24)

                // Video player with keyboard overlay
                if let player = player {
                    ZStack(alignment: .bottom) {
                        VideoPlayerView(player: player)
                            .aspectRatio(16/9, contentMode: .fit)
                            .frame(maxWidth: 600)
                            .cornerRadius(12)

                        // Keyboard shortcut overlay at bottom of video
                        if showKeys {
                            HStack(spacing: 8) {
                                ForEach(0..<3, id: \.self) { index in
                                    OnboardingKey(text: keys[index], isPressed: keyStates[index])
                                        .scaleEffect(keyStates[index] ? 1.0 : 0.5)
                                        .opacity(keyStates[index] ? 1.0 : 0.0)
                                        .animation(
                                            .spring(response: 0.35, dampingFraction: 0.6, blendDuration: 0),
                                            value: keyStates[index]
                                        )
                                }
                            }
                            .padding(.bottom, 20)
                        }
                    }
                }

                Spacer()

                // Continue button - same style as WelcomeStep
                Button(action: onNext) {
                    Text("Continue")
                        .font(.custom("Nunito-Bold", size: 17))
                        .foregroundColor(.white)
                        .frame(width: 200, height: 52)
                        .background(
                            ZStack {
                                // Bottom shadow layer (3D effect)
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(hex: "333333"))
                                    .offset(y: 5)

                                // Main button
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(hex: "1a1a1a"))
                            }
                        )
                }
                .buttonStyle(FeaturesNoFadeButtonStyle())

                Spacer()
                    .frame(height: 30)
            }
        }
        .onAppear {
            setupPlayer()
        }
    }

    private func setupPlayer() {
        if let videoURL = Bundle.main.url(forResource: "paso2", withExtension: "mp4") {
            player = AVPlayer(url: videoURL)
            player?.actionAtItemEnd = .none
            player?.isMuted = true

            // Show keys animation when video starts
            showKeysAnimation()

            // Loop video and show keys each time
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player?.currentItem,
                queue: .main
            ) { _ in
                player?.seek(to: .zero)
                player?.play()
                showKeysAnimation()
            }

            player?.play()
        }
    }

    private func showKeysAnimation() {
        // Reset states
        showKeys = true
        keyStates = [false, false, false]

        // Animate each key appearing with delay (like pressing keys)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            keyStates[0] = true // ⌘
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            keyStates[1] = true // ⇧
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            keyStates[2] = true // T
        }

        // Hide keys after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Fade out all keys together
            withAnimation(.easeOut(duration: 0.25)) {
                keyStates = [false, false, false]
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showKeys = false
            }
        }
    }
}

// MARK: - Video Player without controls
struct VideoPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        view.wantsLayer = true
        view.layer = playerLayer
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let playerLayer = nsView.layer as? AVPlayerLayer {
            playerLayer.player = player
        }
    }
}

// MARK: - No Fade Button Style
struct FeaturesNoFadeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(1)
    }
}

// MARK: - 3D Keyboard Key for Onboarding (white style with press effect)
struct OnboardingKey: View {
    let text: String
    var isPressed: Bool = true

    var body: some View {
        ZStack {
            // Bottom layer (3D effect) - darker when pressed
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.4))
                .frame(width: 44, height: 44)
                .offset(y: isPressed ? 2 : 4)

            // Top layer - moves down slightly when pressed
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .frame(width: 44, height: 44)
                .offset(y: isPressed ? 1 : 0)

            Text(text)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.black)
                .offset(y: isPressed ? 1 : 0)
        }
        .frame(width: 44, height: 48)
    }
}
