//
//  OnboardingView.swift
//  typo
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var onboardingManager = OnboardingManager.shared
    @State private var currentStep = 0
    @State private var licenseInput = ""
    @State private var isValidating = false
    @State private var showError = false
    @State private var errorMessage = ""

    var onComplete: () -> Void

    private let totalSteps = 5

    var body: some View {
        Group {
            switch currentStep {
            case 0:
                WelcomeStep(onNext: nextStep)
            case 1:
                FeaturesStep(onNext: nextStep, onBack: previousStep)
            case 2:
                PermissionsStep(onNext: nextStep, onBack: previousStep)
            case 3:
                ShortcutStep(onNext: nextStep, onBack: previousStep)
            case 4:
                ActivationStep(
                    licenseInput: $licenseInput,
                    isValidating: $isValidating,
                    showError: $showError,
                    errorMessage: $errorMessage,
                    onActivate: activateLicense,
                    onBack: previousStep
                )
            default:
                EmptyView()
            }
        }
        .frame(width: 800, height: 520)
    }

    private func nextStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if currentStep < totalSteps - 1 {
                currentStep += 1
            }
        }
    }

    private func previousStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if currentStep > 0 {
                currentStep -= 1
            }
        }
    }

    private func activateLicense() {
        isValidating = true
        showError = false

        Task {
            let isValid = await onboardingManager.validateLicense(licenseInput)

            await MainActor.run {
                isValidating = false

                if isValid {
                    onboardingManager.completeOnboarding()
                    onComplete()
                } else {
                    showError = true
                    errorMessage = "Invalid license key. Use format: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
                }
            }
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
