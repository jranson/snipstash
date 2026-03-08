//
//  SnippetIcon.swift
//

import SwiftUI
import AppKit

/// A classic heart shape: two rounded lobes at top, pointed bottom.
/// Returns a path suitable for use as a cutout (even-odd fill).
private func heartPath(in rect: CGRect) -> Path {
    var path = Path()
    let w = rect.width
    let h = rect.height
    let x = rect.minX
    let y = rect.minY

    // Start at the top-center dip between the two lobes
    path.move(to: CGPoint(x: x + w * 0.5, y: y + h * 0.28))

    // Right lobe: arc up and over to the right side
    path.addCurve(
        to: CGPoint(x: x + w, y: y + h * 0.32),
        control1: CGPoint(x: x + w * 0.5, y: y - h * 0.04),
        control2: CGPoint(x: x + w, y: y)
    )
    // Right side sweeping down to the bottom point
    path.addCurve(
        to: CGPoint(x: x + w * 0.5, y: y + h),
        control1: CGPoint(x: x + w, y: y + h * 0.65),
        control2: CGPoint(x: x + w * 0.62, y: y + h * 0.86)
    )
    // Left side sweeping up from the bottom point
    path.addCurve(
        to: CGPoint(x: x, y: y + h * 0.32),
        control1: CGPoint(x: x + w * 0.38, y: y + h * 0.86),
        control2: CGPoint(x: x, y: y + h * 0.65)
    )
    // Left lobe: arc up and over back to the top-center dip
    path.addCurve(
        to: CGPoint(x: x + w * 0.5, y: y + h * 0.28),
        control1: CGPoint(x: x, y: y),
        control2: CGPoint(x: x + w * 0.5, y: y - h * 0.04)
    )
    path.closeSubpath()
    return path
}

/// A shape representing a pad with spiral binding at the top (snippet icon).
/// Portrait orientation with circular holes along the top edge.
struct SnippetIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Pad body: rounded rect, portrait (taller than wide), centered
        let padWidth = rect.width * 0.7
        let padHeight = rect.height * 0.9
        let padX = rect.midX - padWidth / 2
        let padY = rect.midY - padHeight / 2
        let cornerRadius = padWidth * 0.12
        let bodyRect = CGRect(x: padX, y: padY, width: padWidth, height: padHeight)
        path.addRoundedRect(in: bodyRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))

        // Spiral holes along the top edge (use even-odd fill to punch holes)
        let holeDiameter = padWidth * 0.2  // Larger holes for better visibility
        let holeRadius = holeDiameter / 2
        let holeSpacing = holeDiameter * 1.15
        let holeCount = max(3, Int(padWidth / holeSpacing))
        let totalHoleSpan = CGFloat(holeCount - 1) * holeSpacing
        let startX = padX + padWidth / 2 - totalHoleSpan / 2  // Center the hole row on the pad
        let holeY = padY + holeRadius * 1.4

        for i in 0..<holeCount {
            let holeCenter = CGPoint(x: startX + CGFloat(i) * holeSpacing, y: holeY)
            path.addEllipse(in: CGRect(
                x: holeCenter.x - holeRadius,
                y: holeCenter.y - holeRadius,
                width: holeDiameter,
                height: holeDiameter
            ))
        }

        // Heart cutout on cover (even-odd: shows menu bar through)
        let heartSize = padWidth * 0.7
        let heartRect = CGRect(
            x: padX + (padWidth - heartSize) / 2,
            y: padY + padHeight * 0.35,
            width: heartSize,
            height: heartSize
        )
        path.addPath(heartPath(in: heartRect))

        return path
    }
}

/// A SwiftUI view displaying the snippet icon shape with a heart cutout on the cover.
/// Uses even-odd fill so spiral holes and heart are punched out (menu bar shows through).
struct SnippetIconView: View {
    var body: some View {
        SnippetIconShape()
            .fill(Color.primary, style: FillStyle(eoFill: true))
            .aspectRatio(1, contentMode: .fit)
    }
}

/// Provides methods for generating a template NSImage of the snippet icon for macOS menu bar usage.
enum SnippetMenubarIcon {
    @MainActor
    static func makeTemplateImage(pointSize: CGFloat = 18, scale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2) -> NSImage {
        let view = SnippetIconView()
            .frame(width: pointSize, height: pointSize)

        let renderer = ImageRenderer(content: view)
        renderer.scale = scale

        guard let nsImage = renderer.nsImage else {
            return NSImage(size: NSSize(width: pointSize, height: pointSize))
        }

        nsImage.isTemplate = true
        nsImage.size = NSSize(width: pointSize, height: pointSize)
        return nsImage
    }
}
