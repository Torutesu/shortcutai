import SwiftUI

// MARK: - Animated Cat Logo Component
// Reusable animated cat logo /\_/\ ( o.o )

struct AnimatedCatLogo: View {
    @Environment(\.colorScheme) var colorScheme

    var subtitle: String = "Powered by Claude"
    var linkURL: String? = "https://claude.ai"
    var scale: CGFloat = 1.5

    private var strokeColor: Color {
        Color.gray
    }

    var body: some View {
        VStack(spacing: 8) {
            TimelineView(.animation(minimumInterval: 0.016)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let phase = time.truncatingRemainder(dividingBy: 5.0) / 5.0 // 5 second cycle

                Canvas { context, size in
                    let offsetX = (size.width - 40 * scale) / 2
                    let offsetY = (size.height - 36 * scale) / 2

                    // Calculate ear rotations based on phase
                    let leftEarRotation = calculateLeftEarRotation(phase: phase)
                    let rightEarRotation = calculateRightEarRotation(phase: phase)

                    // Calculate eye animation
                    let (eyeOffsetX, eyeOffsetY, eyeScaleY) = calculateEyeAnimation(phase: phase)

                    // Draw left ear /\
                    var leftEarPath = Path()
                    leftEarPath.move(to: CGPoint(x: 8 * scale + offsetX, y: 14 * scale + offsetY))
                    leftEarPath.addLine(to: CGPoint(x: 12 * scale + offsetX, y: 2 * scale + offsetY))
                    leftEarPath.addLine(to: CGPoint(x: 16 * scale + offsetX, y: 14 * scale + offsetY))

                    // Apply rotation to left ear
                    let leftEarCenter = CGPoint(x: 16 * scale + offsetX, y: 14 * scale + offsetY)
                    var leftEarTransform = CGAffineTransform.identity
                    leftEarTransform = leftEarTransform.translatedBy(x: leftEarCenter.x, y: leftEarCenter.y)
                    leftEarTransform = leftEarTransform.rotated(by: leftEarRotation * .pi / 180)
                    leftEarTransform = leftEarTransform.translatedBy(x: -leftEarCenter.x, y: -leftEarCenter.y)
                    let transformedLeftEar = leftEarPath.applying(leftEarTransform)

                    context.stroke(transformedLeftEar, with: .color(strokeColor), style: StrokeStyle(lineWidth: 3.0, lineCap: .round, lineJoin: .round))

                    // Draw right ear /\
                    var rightEarPath = Path()
                    rightEarPath.move(to: CGPoint(x: 24 * scale + offsetX, y: 14 * scale + offsetY))
                    rightEarPath.addLine(to: CGPoint(x: 28 * scale + offsetX, y: 2 * scale + offsetY))
                    rightEarPath.addLine(to: CGPoint(x: 32 * scale + offsetX, y: 14 * scale + offsetY))

                    // Apply rotation to right ear
                    let rightEarCenter = CGPoint(x: 24 * scale + offsetX, y: 14 * scale + offsetY)
                    var rightEarTransform = CGAffineTransform.identity
                    rightEarTransform = rightEarTransform.translatedBy(x: rightEarCenter.x, y: rightEarCenter.y)
                    rightEarTransform = rightEarTransform.rotated(by: rightEarRotation * .pi / 180)
                    rightEarTransform = rightEarTransform.translatedBy(x: -rightEarCenter.x, y: -rightEarCenter.y)
                    let transformedRightEar = rightEarPath.applying(rightEarTransform)

                    context.stroke(transformedRightEar, with: .color(strokeColor), style: StrokeStyle(lineWidth: 3.0, lineCap: .round, lineJoin: .round))

                    // Draw connecting line _
                    var linePath = Path()
                    linePath.move(to: CGPoint(x: 16 * scale + offsetX, y: 14 * scale + offsetY))
                    linePath.addLine(to: CGPoint(x: 24 * scale + offsetX, y: 14 * scale + offsetY))
                    context.stroke(linePath, with: .color(strokeColor), style: StrokeStyle(lineWidth: 3.0, lineCap: .round))

                    // Draw left face curve (
                    var leftFacePath = Path()
                    leftFacePath.move(to: CGPoint(x: 6 * scale + offsetX, y: 20 * scale + offsetY))
                    leftFacePath.addQuadCurve(
                        to: CGPoint(x: 8 * scale + offsetX, y: 32 * scale + offsetY),
                        control: CGPoint(x: 2 * scale + offsetX, y: 26 * scale + offsetY)
                    )
                    context.stroke(leftFacePath, with: .color(strokeColor), style: StrokeStyle(lineWidth: 3.0, lineCap: .round))

                    // Draw right face curve )
                    var rightFacePath = Path()
                    rightFacePath.move(to: CGPoint(x: 34 * scale + offsetX, y: 20 * scale + offsetY))
                    rightFacePath.addQuadCurve(
                        to: CGPoint(x: 32 * scale + offsetX, y: 32 * scale + offsetY),
                        control: CGPoint(x: 38 * scale + offsetX, y: 26 * scale + offsetY)
                    )
                    context.stroke(rightFacePath, with: .color(strokeColor), style: StrokeStyle(lineWidth: 3.0, lineCap: .round))

                    // Draw left eye o
                    let leftEyeX = 14 * scale + offsetX + eyeOffsetX
                    let leftEyeY = 24 * scale + offsetY + eyeOffsetY
                    var leftEyePath = Path()
                    leftEyePath.addEllipse(in: CGRect(
                        x: leftEyeX - 2.5 * scale,
                        y: leftEyeY - 2.5 * scale * eyeScaleY,
                        width: 5 * scale,
                        height: 5 * scale * eyeScaleY
                    ))
                    context.fill(leftEyePath, with: .color(strokeColor))

                    // Draw right eye o
                    let rightEyeX = 26 * scale + offsetX + eyeOffsetX
                    let rightEyeY = 24 * scale + offsetY + eyeOffsetY
                    var rightEyePath = Path()
                    rightEyePath.addEllipse(in: CGRect(
                        x: rightEyeX - 2.5 * scale,
                        y: rightEyeY - 2.5 * scale * eyeScaleY,
                        width: 5 * scale,
                        height: 5 * scale * eyeScaleY
                    ))
                    context.fill(rightEyePath, with: .color(strokeColor))
                }
            }
            .frame(width: 70, height: 60)

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundColor(strokeColor)
        }
        .opacity(1.0)
        .onTapGesture {
            if let urlString = linkURL, let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }
        .onHover { hovering in
            if linkURL != nil {
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
    }

    private func calculateLeftEarRotation(phase: CGFloat) -> CGFloat {
        if phase < 0.09 { return 0 }
        if phase < 0.12 { return interpolate(phase, from: 0.09, to: 0.12, valueFrom: 0, valueTo: -6) }
        if phase < 0.16 { return interpolate(phase, from: 0.12, to: 0.16, valueFrom: -6, valueTo: 0) }
        if phase < 0.34 { return 0 }
        if phase < 0.38 { return interpolate(phase, from: 0.34, to: 0.38, valueFrom: 0, valueTo: -10) }
        if phase < 0.42 { return interpolate(phase, from: 0.38, to: 0.42, valueFrom: -10, valueTo: -4) }
        if phase < 0.48 { return interpolate(phase, from: 0.42, to: 0.48, valueFrom: -4, valueTo: 0) }
        return 0
    }

    private func calculateRightEarRotation(phase: CGFloat) -> CGFloat {
        if phase < 0.09 { return 0 }
        if phase < 0.12 { return interpolate(phase, from: 0.09, to: 0.12, valueFrom: 0, valueTo: 6) }
        if phase < 0.16 { return interpolate(phase, from: 0.12, to: 0.16, valueFrom: 6, valueTo: 0) }
        if phase < 0.34 { return 0 }
        if phase < 0.38 { return interpolate(phase, from: 0.34, to: 0.38, valueFrom: 0, valueTo: 10) }
        if phase < 0.42 { return interpolate(phase, from: 0.38, to: 0.42, valueFrom: 10, valueTo: 4) }
        if phase < 0.48 { return interpolate(phase, from: 0.42, to: 0.48, valueFrom: 4, valueTo: 0) }
        if phase < 0.71 { return 0 }
        if phase < 0.74 { return interpolate(phase, from: 0.71, to: 0.74, valueFrom: 0, valueTo: 6) }
        if phase < 0.78 { return interpolate(phase, from: 0.74, to: 0.78, valueFrom: 6, valueTo: 0) }
        return 0
    }

    private func calculateEyeAnimation(phase: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
        if phase < 0.08 { return (0, 0, 1) }
        if phase < 0.10 { return (interpolate(phase, from: 0.08, to: 0.10, valueFrom: 0, valueTo: 1), 0, 1) }
        if phase < 0.18 { return (1, 0, 1) }
        if phase < 0.20 { return (1, 0, interpolate(phase, from: 0.18, to: 0.20, valueFrom: 1, valueTo: 0.1)) }
        if phase < 0.22 { return (1, 0, 0.1) }
        if phase < 0.24 { return (1, 0, interpolate(phase, from: 0.22, to: 0.24, valueFrom: 0.1, valueTo: 1)) }
        if phase < 0.32 { return (1, 0, 1) }
        if phase < 0.35 { return (interpolate(phase, from: 0.32, to: 0.35, valueFrom: 1, valueTo: -0.5), interpolate(phase, from: 0.32, to: 0.35, valueFrom: 0, valueTo: -0.5), 1) }
        if phase < 0.48 { return (-0.5, -0.5, 1) }
        if phase < 0.52 { return (interpolate(phase, from: 0.48, to: 0.52, valueFrom: -0.5, valueTo: 0), interpolate(phase, from: 0.48, to: 0.52, valueFrom: -0.5, valueTo: 0), 1) }
        if phase < 0.54 { return (0, 0, interpolate(phase, from: 0.52, to: 0.54, valueFrom: 1, valueTo: 0.1)) }
        if phase < 0.56 { return (0, 0, interpolate(phase, from: 0.54, to: 0.56, valueFrom: 0.1, valueTo: 1)) }
        if phase < 0.68 { return (0, 0, 1) }
        if phase < 0.72 { return (interpolate(phase, from: 0.68, to: 0.72, valueFrom: 0, valueTo: -0.5), interpolate(phase, from: 0.68, to: 0.72, valueFrom: 0, valueTo: 0.5), 1) }
        if phase < 0.82 { return (-0.5, 0.5, 1) }
        if phase < 0.85 { return (interpolate(phase, from: 0.82, to: 0.85, valueFrom: -0.5, valueTo: 0), interpolate(phase, from: 0.82, to: 0.85, valueFrom: 0.5, valueTo: 0), 1) }
        return (0, 0, 1)
    }

    private func interpolate(_ value: CGFloat, from: CGFloat, to: CGFloat, valueFrom: CGFloat, valueTo: CGFloat) -> CGFloat {
        let progress = (value - from) / (to - from)
        return valueFrom + (valueTo - valueFrom) * progress
    }
}

#Preview {
    VStack(spacing: 40) {
        AnimatedCatLogo()
        AnimatedCatLogo(subtitle: "© 2026 All rights reserved.", linkURL: nil)
        AnimatedCatLogo(subtitle: "Custom text", scale: 2.0)
    }
    .padding(40)
}
