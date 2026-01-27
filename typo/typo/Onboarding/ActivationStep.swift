//
//  ActivationStep.swift
//  typo
//

import SwiftUI

struct ActivationStep: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false

    var onComplete: () -> Void
    var onBack: () -> Void

    // Pastel peach/coral color for the right side
    private let brandPastel = Color(hex: "F5D0C5")
    private let placeholderGray = Color(hex: "b0b0b0")

    var body: some View {
        HStack(spacing: 0) {
            // Left side - White form
            ZStack(alignment: .trailing) {
                Color.white

                VStack(alignment: .leading, spacing: 0) {
                    Spacer()
                        .frame(height: 40)

                    Text(isSignUp ? "Create Account" : "Sign In")
                        .font(.nunitoBold(size: 32))
                        .foregroundColor(Color(hex: "1a1a1a"))

                    Spacer()
                        .frame(height: 10)

                    Text("Sign in to sync your actions\nacross devices.")
                        .font(.nunitoRegularBold(size: 14))
                        .foregroundColor(Color(hex: "666666"))
                        .lineSpacing(3)

                    Spacer()
                        .frame(height: 30)

                    // Email field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email")
                            .font(.nunitoRegularBold(size: 14))
                            .foregroundColor(Color(hex: "333333"))

                        CustomTextField(text: $email, placeholder: "you@example.com")
                            .frame(height: 20)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(hex: "f5f5f5"))
                            )
                    }

                    Spacer()
                        .frame(height: 16)

                    // Password field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password")
                            .font(.nunitoRegularBold(size: 14))
                            .foregroundColor(Color(hex: "333333"))

                        CustomSecureField(text: $password, placeholder: "••••••••")
                            .frame(height: 20)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(hex: "f5f5f5"))
                            )
                    }

                    // Error message
                    if let error = authManager.errorMessage {
                        Text(error)
                            .font(.nunitoRegularBold(size: 12))
                            .foregroundColor(.red)
                            .padding(.top, 10)
                    }

                    Spacer()
                        .frame(height: 24)

                    // Sign In / Sign Up button - Black style like Google button
                    Button(action: {
                        Task {
                            do {
                                if isSignUp {
                                    try await authManager.signUp(email: email, password: password)
                                } else {
                                    try await authManager.signIn(email: email, password: password)
                                }
                                await MainActor.run {
                                    OnboardingManager.shared.completeOnboarding()
                                    onComplete()
                                }
                            } catch {
                                await MainActor.run {
                                    authManager.errorMessage = error.localizedDescription
                                }
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            if authManager.isLoading {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(authManager.isLoading ? (isSignUp ? "Creating..." : "Signing in...") : (isSignUp ? "Create Account" : "Sign In"))
                        }
                        .font(.nunitoBold(size: 15))
                        .foregroundColor(!email.isEmpty && !password.isEmpty ? .white : Color(hex: "999999"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(!email.isEmpty && !password.isEmpty ? Color(hex: "333333") : Color(hex: "e0e0e0"))
                                    .offset(y: 5)

                                RoundedRectangle(cornerRadius: 14)
                                    .fill(!email.isEmpty && !password.isEmpty ? Color(hex: "1a1a1a") : Color(hex: "cccccc"))
                            }
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(email.isEmpty || password.isEmpty || authManager.isLoading)

                    Spacer()
                        .frame(height: 16)

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color(hex: "e0e0e0"))
                            .frame(height: 1)
                        Text("or")
                            .font(.nunitoRegularBold(size: 12))
                            .foregroundColor(Color(hex: "999999"))
                            .padding(.horizontal, 8)
                        Rectangle()
                            .fill(Color(hex: "e0e0e0"))
                            .frame(height: 1)
                    }

                    Spacer()
                        .frame(height: 16)

                    // Google Sign In button
                    Button(action: {
                        authManager.signInWithGoogle()
                        // Listen for OAuth success
                        NotificationCenter.default.addObserver(forName: NSNotification.Name("OAuthLoginSuccess"), object: nil, queue: .main) { _ in
                            OnboardingManager.shared.completeOnboarding()
                            onComplete()
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image("google")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 18, height: 18)
                            Text("Continue with Google")
                                .font(.nunitoBold(size: 15))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(hex: "333333"))
                                    .offset(y: 5)

                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(hex: "1a1a1a"))
                            }
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()
                        .frame(height: 20)

                    // Toggle sign up/sign in
                    HStack(spacing: 4) {
                        Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                            .font(.nunitoRegularBold(size: 13))
                            .foregroundColor(Color(hex: "666666"))

                        Button(action: {
                            withAnimation {
                                isSignUp.toggle()
                                authManager.errorMessage = nil
                            }
                        }) {
                            Text(isSignUp ? "Sign In" : "Sign Up")
                                .font(.nunitoBold(size: 13))
                                .foregroundColor(Color(hex: "1a1a1a"))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                        .frame(height: 30)
                }
                .padding(.horizontal, 32)
                .padding(.trailing, 24)

                // Wavy edge
                WavyEdgePastel()
                    .frame(width: 22)
                    .offset(x: 10)
            }
            .frame(width: 340)

            // Right side - Pastel with app icon
            ZStack {
                brandPastel

                // App icon
                Image("logo textab")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 220, height: 220)
                    .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
            }
            .frame(maxWidth: .infinity)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Wavy Edge Pastel

struct WavyEdgePastel: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let width = geo.size.width
                let height = geo.size.height
                let notchRadius: CGFloat = 4
                let notchSpacing: CGFloat = 20

                // Start from top-right corner
                path.move(to: CGPoint(x: width, y: 0))
                path.addLine(to: CGPoint(x: width, y: height))
                path.addLine(to: CGPoint(x: 0, y: height))

                // Create semicircular notches from bottom to top (biting into the right/colored side)
                var y: CGFloat = height - notchSpacing / 2

                while y > 0 {
                    // Line up to notch
                    path.addLine(to: CGPoint(x: 0, y: y + notchRadius))

                    // Semicircle notch biting to the right (into the colored area)
                    path.addArc(
                        center: CGPoint(x: 0, y: y),
                        radius: notchRadius,
                        startAngle: .degrees(90),
                        endAngle: .degrees(-90),
                        clockwise: true
                    )

                    y -= notchSpacing
                }

                // Line to top
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: width, y: 0))
                path.closeSubpath()
            }
            .fill(Color(hex: "F5D0C5"))
        }
    }
}

// MARK: - Custom TextField with NSTextField

struct CustomTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = NSFont(name: "Nunito-Bold", size: 15) ?? NSFont.systemFont(ofSize: 15)
        textField.textColor = NSColor.black
        textField.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: NSColor.gray.withAlphaComponent(0.5),
                .font: NSFont(name: "Nunito-Bold", size: 15) ?? NSFont.systemFont(ofSize: 15)
            ]
        )
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CustomTextField

        init(_ parent: CustomTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
    }
}

struct CustomSecureField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeNSView(context: Context) -> NSSecureTextField {
        let textField = NSSecureTextField()
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = NSFont(name: "Nunito-Bold", size: 15) ?? NSFont.systemFont(ofSize: 15)
        textField.textColor = NSColor.black
        textField.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: NSColor.gray.withAlphaComponent(0.5),
                .font: NSFont(name: "Nunito-Bold", size: 15) ?? NSFont.systemFont(ofSize: 15)
            ]
        )
        return textField
    }

    func updateNSView(_ nsView: NSSecureTextField, context: Context) {
        nsView.stringValue = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CustomSecureField

        init(_ parent: CustomSecureField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
    }
}
