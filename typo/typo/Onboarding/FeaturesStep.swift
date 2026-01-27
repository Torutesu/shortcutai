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
    @State private var wavePhase: CGFloat = 0

    private let keys = ["⌘", "⇧", "T"]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Full gradient background (no wave, just solid gradient like step 1 after wave rises)
                LinearGradient(
                    colors: [
                        Color(hex: "E8909C"),
                        Color(hex: "F4A5B0"),
                        Color(hex: "FBBAC4"),
                        Color(hex: "FDD5DB")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Wave at top for visual effect
                FeaturesWaveShape(phase: wavePhase, frequency: 2, amplitude: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "E8909C"),
                                Color(hex: "F4A5B0")
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 100)
                    .offset(y: -geo.size.height / 2 + 50)

                // Content centered
                VStack(spacing: 40) {
                    VStack(spacing: 20) {
                        Text("How to open TexTab")
                            .font(.custom("Nunito-Black", size: 32))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 3)

                        // Video player with keyboard overlay
                        if let player = player {
                            ZStack(alignment: .bottom) {
                                VideoPlayerView(player: player)
                                    .aspectRatio(16/9, contentMode: .fit)
                                    .frame(maxWidth: 580)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                    )
                                    .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)

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
                    }

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
                }
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            .onAppear {
                setupPlayer()
                // Continuous wave animation
                withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                    wavePhase = .pi * 2
                }
            }
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

// MARK: - Wave Shape
struct FeaturesWaveShape: Shape {
    var phase: CGFloat
    var frequency: CGFloat
    var amplitude: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width, y: 0))

        for x in stride(from: rect.width, through: 0, by: -2) {
            let normalizedX = x / rect.width
            let y = sin(normalizedX * .pi * frequency + phase) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.closeSubpath()
        return path
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
