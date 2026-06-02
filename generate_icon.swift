#!/usr/bin/env swift
// Generates the Sleepless app icon at multiple sizes.
// Run: swift generate_icon.swift
// Output: AppIcon.png (1024x1024) + smaller sizes in Icons/

import AppKit
import Foundation

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let s = size // shorthand

    // --- Background: dark navy rounded rect ---
    let bgRect = CGRect(x: 0, y: 0, width: s, height: s)
    let cornerRadius = s * 0.22 // macOS icon corner radius
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Gradient background: deep navy to dark indigo
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        CGColor(red: 0.08, green: 0.08, blue: 0.20, alpha: 1.0),  // dark navy
        CGColor(red: 0.12, green: 0.10, blue: 0.30, alpha: 1.0),  // dark indigo
    ] as CFArray

    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()

    if let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(gradient,
            start: CGPoint(x: 0, y: s),
            end: CGPoint(x: s, y: 0),
            options: [])
    }
    ctx.restoreGState()

    // --- Crescent moon ---
    let moonCenterX = s * 0.38
    let moonCenterY = s * 0.55
    let moonRadius = s * 0.28

    // Full circle for the moon
    let moonPath = CGMutablePath()
    moonPath.addArc(center: CGPoint(x: moonCenterX, y: moonCenterY),
                    radius: moonRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)

    // Cut-out circle (shifted right and up to create crescent)
    let cutCenterX = moonCenterX + moonRadius * 0.55
    let cutCenterY = moonCenterY + moonRadius * 0.25
    let cutRadius = moonRadius * 0.78

    let cutPath = CGMutablePath()
    cutPath.addArc(center: CGPoint(x: cutCenterX, y: cutCenterY),
                   radius: cutRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)

    // Draw moon with cutout using even-odd fill
    let crescentPath = CGMutablePath()
    crescentPath.addPath(moonPath)
    crescentPath.addPath(cutPath)

    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()

    // Moon color: warm pale yellow
    ctx.setFillColor(CGColor(red: 0.95, green: 0.90, blue: 0.70, alpha: 1.0))
    ctx.addPath(crescentPath)
    ctx.fillPath(using: .evenOdd)

    // --- Subtle moon glow ---
    let glowRadius = moonRadius * 1.6
    let glowColors = [
        CGColor(red: 0.95, green: 0.90, blue: 0.70, alpha: 0.15),
        CGColor(red: 0.95, green: 0.90, blue: 0.70, alpha: 0.0),
    ] as CFArray
    if let glowGradient = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(glowGradient,
            startCenter: CGPoint(x: moonCenterX, y: moonCenterY), startRadius: moonRadius * 0.5,
            endCenter: CGPoint(x: moonCenterX, y: moonCenterY), endRadius: glowRadius,
            options: [])
    }

    // --- "Z z z" letters floating up-right from the moon ---
    let zPositions: [(x: CGFloat, y: CGFloat, size: CGFloat, alpha: CGFloat)] = [
        (s * 0.58, s * 0.52, s * 0.11, 0.9),   // closest Z — largest
        (s * 0.70, s * 0.38, s * 0.08, 0.6),   // middle z
        (s * 0.79, s * 0.27, s * 0.06, 0.35),  // farthest z — smallest, faintest
    ]

    for z in zPositions {
        let font = NSFont.systemFont(ofSize: z.size, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(red: 0.75, green: 0.82, blue: 0.95, alpha: z.alpha),
        ]
        let str = NSAttributedString(string: "z", attributes: attributes)
        let line = CTLineCreateWithAttributedString(str)
        let bounds = CTLineGetBoundsWithOptions(line, [])

        ctx.saveGState()
        // Slight rotation for each Z
        let angle: CGFloat = -0.15
        ctx.translateBy(x: z.x, y: z.y)
        ctx.rotate(by: angle)
        ctx.translateBy(x: -bounds.width / 2, y: -bounds.height / 2)

        let textPos = CGPoint(x: 0, y: 0)
        ctx.textPosition = textPos
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    // --- Small stars ---
    let starPositions: [(x: CGFloat, y: CGFloat, r: CGFloat, alpha: CGFloat)] = [
        (s * 0.82, s * 0.72, s * 0.012, 0.7),
        (s * 0.75, s * 0.82, s * 0.008, 0.5),
        (s * 0.18, s * 0.80, s * 0.010, 0.6),
        (s * 0.88, s * 0.55, s * 0.007, 0.4),
        (s * 0.15, s * 0.35, s * 0.009, 0.5),
        (s * 0.65, s * 0.85, s * 0.006, 0.35),
    ]

    for star in starPositions {
        ctx.setFillColor(CGColor(red: 0.90, green: 0.92, blue: 1.0, alpha: star.alpha))
        ctx.fillEllipse(in: CGRect(
            x: star.x - star.r, y: star.y - star.r,
            width: star.r * 2, height: star.r * 2))
    }

    ctx.restoreGState()
    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to generate PNG")
        return
    }
    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("Saved: \(path)")
    } catch {
        print("Failed to write \(path): \(error)")
    }
}

// Generate icons
let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().path
let baseDir = scriptDir.isEmpty ? "." : scriptDir

// Main icon
let icon1024 = drawIcon(size: 1024)
savePNG(icon1024, to: "\(baseDir)/AppIcon.png")

// Sizes needed for App Store / asset catalog
let sizes = [16, 32, 64, 128, 256, 512, 1024]
let iconsDir = "\(baseDir)/Icons"
try? FileManager.default.createDirectory(atPath: iconsDir, withIntermediateDirectories: true)

for size in sizes {
    let icon = drawIcon(size: CGFloat(size))
    savePNG(icon, to: "\(iconsDir)/icon_\(size)x\(size).png")
}

print("\nDone! Icons generated in \(iconsDir)/")
