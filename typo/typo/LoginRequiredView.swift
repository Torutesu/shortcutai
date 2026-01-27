//
//  LoginRequiredView.swift
//  typo
//
//  Login view displayed when user is not authenticated
//

import SwiftUI

struct LoginRequiredView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var showForgotPassword = false
    @State private var forgotPasswordEmail = ""
    @State private var showPasswordResetSent = false

    // Pastel peach/coral color for the right side
    private let brandPastel = Color(hex: "F5D0C5")

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left side - White form
                ZStack(alignment: .trailing) {
                    Color.white

                    VStack(alignment: .leading, spacing: 0) {
                        Spacer()
                            .frame(height: 60)

                    Text(isSignUp ? "Create Account" : "Sign In")
                        .font(.nunitoBold(size: 32))
                        .foregroundColor(Color(hex: "1a1a1a"))

                    Spacer()
                        .frame(height: 10)

                    Text("Sign in to access your actions\nand settings.")
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

                        LoginCustomTextField(text: $email, placeholder: "you@example.com")
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

                        LoginCustomSecureField(text: $password, placeholder: "••••••••")
                            .frame(height: 20)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(hex: "f5f5f5"))
                            )
                    }

                    // Forgot password (only for sign in)
                    if !isSignUp {
                        HStack {
                            Spacer()
                            Button(action: {
                                forgotPasswordEmail = email
                                showForgotPassword = true
                            }) {
                                Text("Forgot password?")
                                    .font(.nunitoRegularBold(size: 12))
                                    .foregroundColor(Color(hex: "1a1a1a"))
                            }
                            .buttonStyle(.plain)
                            .pointerCursor()
                        }
                        .padding(.top, 8)
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

                    // Sign In / Sign Up button - Black 3D style
                    Button(action: {
                        Task {
                            do {
                                if isSignUp {
                                    try await authManager.signUp(email: email, password: password)
                                } else {
                                    try await authManager.signIn(email: email, password: password)
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
                            Group {
                                if !email.isEmpty && !password.isEmpty {
                                    // Enabled: 3D effect
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color(hex: "333333"))
                                            .offset(y: 5)
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color(hex: "1a1a1a"))
                                    }
                                } else {
                                    // Disabled: flat like inputs
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color(hex: "e8e8e8"))
                                }
                            }
                        )
                    }
                    .buttonStyle(NoFadeButtonStyle())
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
                    .buttonStyle(NoFadeButtonStyle())

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
                LoginWavyEdgePastel()
                    .frame(width: 22)
                    .offset(x: 10)
            }
            .frame(width: 340, height: geometry.size.height)

            // Right side - Pastel with app icon (fixed height)
            ZStack {
                brandPastel

                // App icon
                Image("logo textab")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 220, height: 220)
                    .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
            }
            .frame(width: geometry.size.width - 340, height: geometry.size.height)
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showForgotPassword) {
            forgotPasswordSheet
        }
        .alert("Password Reset Sent", isPresented: $showPasswordResetSent) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Check your email for a password reset link.")
        }
    }

    // MARK: - Forgot Password Sheet

    private var forgotPasswordSheet: some View {
        VStack(spacing: 20) {
            Text("Reset Password")
                .font(.nunitoBold(size: 20))

            Text("Enter your email and we'll send you a link to reset your password.")
                .font(.nunitoRegularBold(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            TextField("Email", text: $forgotPasswordEmail)
                .textFieldStyle(.plain)
                .font(.nunitoRegularBold(size: 14))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )

            HStack(spacing: 12) {
                Button("Cancel") {
                    showForgotPassword = false
                }
                .buttonStyle(.plain)

                Button(action: {
                    Task {
                        do {
                            try await authManager.sendPasswordReset(email: forgotPasswordEmail)
                            showForgotPassword = false
                            showPasswordResetSent = true
                        } catch {
                            authManager.errorMessage = error.localizedDescription
                        }
                    }
                }) {
                    Text("Send Reset Link")
                        .font(.nunitoBold(size: 14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: "1a1a1a"))
                        )
                }
                .buttonStyle(.plain)
                .disabled(forgotPasswordEmail.isEmpty)
            }
        }
        .padding(30)
        .frame(width: 400)
    }
}

// MARK: - Login Wavy Edge Pastel (Vertical - Left side)

struct LoginWavyEdgePastel: View {
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

// MARK: - Login Custom TextField

struct LoginCustomTextField: NSViewRepresentable {
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
        var parent: LoginCustomTextField

        init(_ parent: LoginCustomTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
    }
}

// MARK: - Login Custom Secure Field

struct LoginCustomSecureField: NSViewRepresentable {
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
        var parent: LoginCustomSecureField

        init(_ parent: LoginCustomSecureField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
    }
}

// MARK: - No Fade Button Style

struct NoFadeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(1)
    }
}

// MARK: - Preview

#Preview {
    LoginRequiredView()
        .frame(width: 700, height: 520)
}
