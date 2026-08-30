#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

/// Deterministic, project-owned source for the NEXUS macOS application icon.
///
/// Run from the project root:
/// `swift DesignAssets/AppIcon/render_app_icon.swift`
///
/// The renderer draws every representation at its native pixel size so the
/// globe remains crisp in Finder and the Dock, including 16–64 px sizes.
private enum NEXUSAppIconRenderer {
    private static let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("NEXUS/Resources/Assets.xcassets/AppIcon.appiconset", isDirectory: true)

    private static let representations: [(filename: String, pixels: Int)] = [
        ("NEXUS-AppIcon-16.png", 16),
        ("NEXUS-AppIcon-16@2x.png", 32),
        ("NEXUS-AppIcon-32.png", 32),
        ("NEXUS-AppIcon-32@2x.png", 64),
        ("NEXUS-AppIcon-128.png", 128),
        ("NEXUS-AppIcon-128@2x.png", 256),
        ("NEXUS-AppIcon-256.png", 256),
        ("NEXUS-AppIcon-256@2x.png", 512),
        ("NEXUS-AppIcon-512.png", 512),
        ("NEXUS-AppIcon-1024.png", 1024),
    ]

    static func run() throws {
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        for representation in representations {
            let data = try renderPNG(pixels: representation.pixels)
            try data.write(
                to: outputDirectory.appendingPathComponent(representation.filename),
                options: .atomic
            )
        }
    }

    private static func renderPNG(pixels: Int) throws -> Data {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bitmapFormat: [],
            bytesPerRow: pixels * 4,
            bitsPerPixel: 32
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap)?.cgContext else {
            throw NSError(domain: "NEXUSAppIconRenderer", code: 1)
        }

        let side = CGFloat(pixels)
        let scale = side / 1024
        let canvas = CGRect(x: 0, y: 0, width: side, height: side)
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.clear(canvas)

        drawBackground(in: context, canvas: canvas, scale: scale)
        drawNetworkCore(in: context, canvas: canvas, scale: scale)

        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "NEXUSAppIconRenderer", code: 2)
        }
        return data
    }

    private static func drawBackground(in context: CGContext, canvas: CGRect, scale: CGFloat) {
        let inset = 28 * scale
        let iconRect = canvas.insetBy(dx: inset, dy: inset)
        let iconPath = CGPath(
            roundedRect: iconRect,
            cornerWidth: 224 * scale,
            cornerHeight: 224 * scale,
            transform: nil
        )

        context.saveGState()
        context.addPath(iconPath)
        context.clip()

        let colors = [
            CGColor(srgbRed: 0.025, green: 0.075, blue: 0.044, alpha: 1),
            CGColor(srgbRed: 0.010, green: 0.026, blue: 0.017, alpha: 1),
        ] as CFArray
        let locations: [CGFloat] = [0, 1]
        if let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: locations) {
            context.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: canvas.midX, y: canvas.midY + 76 * scale),
                startRadius: 0,
                endCenter: canvas.center,
                endRadius: 700 * scale,
                options: [.drawsAfterEndLocation]
            )
        }

        context.setFillColor(CGColor(srgbRed: 0.10, green: 0.44, blue: 0.25, alpha: 0.055))
        context.fillEllipse(in: CGRect(
            x: canvas.midX - 390 * scale,
            y: canvas.midY - 350 * scale,
            width: 780 * scale,
            height: 700 * scale
        ))
        context.restoreGState()

        context.saveGState()
        context.addPath(iconPath)
        context.setStrokeColor(CGColor(srgbRed: 0.24, green: 0.80, blue: 0.46, alpha: 0.22))
        context.setLineWidth(max(1, 4 * scale))
        context.strokePath()
        context.restoreGState()
    }

    private static func drawNetworkCore(in context: CGContext, canvas: CGRect, scale: CGFloat) {
        let center = CGPoint(x: canvas.midX, y: canvas.midY + 12 * scale)
        let radius = 290 * scale
        let glow = CGColor(srgbRed: 0.20, green: 1.00, blue: 0.52, alpha: 0.70)
        let bright = CGColor(srgbRed: 0.31, green: 1.00, blue: 0.61, alpha: 0.96)
        let structural = CGColor(srgbRed: 0.24, green: 0.93, blue: 0.51, alpha: 0.62)
        let subtle = CGColor(srgbRed: 0.20, green: 0.89, blue: 0.47, alpha: 0.35)

        // Two restrained network connections sit behind the globe.
        context.saveGState()
        context.setStrokeColor(subtle)
        context.setLineWidth(max(0.75, 5 * scale))
        context.setLineCap(.round)
        context.move(to: CGPoint(x: center.x - 352 * scale, y: center.y + 172 * scale))
        context.addLine(to: CGPoint(x: center.x - 198 * scale, y: center.y + 102 * scale))
        context.move(to: CGPoint(x: center.x + 218 * scale, y: center.y - 110 * scale))
        context.addLine(to: CGPoint(x: center.x + 370 * scale, y: center.y - 206 * scale))
        context.strokePath()
        context.restoreGState()

        // A single inclined orbit gives the network core its distinctive silhouette.
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: -0.34)
        context.translateBy(x: -center.x, y: -center.y)
        context.setStrokeColor(subtle)
        context.setLineWidth(max(0.75, 6 * scale))
        context.strokeEllipse(in: CGRect(
            x: center.x - 390 * scale,
            y: center.y - 122 * scale,
            width: 780 * scale,
            height: 244 * scale
        ))
        context.restoreGState()

        let globeRect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )

        // A modest halo supports the phosphor identity without becoming neon.
        context.saveGState()
        context.setShadow(offset: .zero, blur: 24 * scale, color: glow)
        context.setStrokeColor(structural)
        context.setLineWidth(max(1, 9 * scale))
        context.strokeEllipse(in: globeRect)
        context.restoreGState()

        context.saveGState()
        context.addEllipse(in: globeRect)
        context.clip()
        context.setStrokeColor(structural)
        context.setLineWidth(max(0.7, 5 * scale))

        // Longitude arcs.
        for widthFactor in [0.72, 1.34] as [CGFloat] {
            let width = radius * widthFactor
            context.strokeEllipse(in: CGRect(
                x: center.x - width / 2,
                y: center.y - radius,
                width: width,
                height: radius * 2
            ))
        }

        // Latitude arcs.
        for offset in [-0.42, 0.42] as [CGFloat] {
            let latitudeY = center.y + radius * offset
            context.strokeEllipse(in: CGRect(
                x: center.x - radius,
                y: latitudeY - radius * 0.27,
                width: radius * 2,
                height: radius * 0.54
            ))
        }

        // Strong, simple equator and central meridian preserve the mark at 16 px.
        context.setStrokeColor(bright)
        context.setLineWidth(max(0.85, 7 * scale))
        context.move(to: CGPoint(x: center.x - radius, y: center.y))
        context.addLine(to: CGPoint(x: center.x + radius, y: center.y))
        context.move(to: CGPoint(x: center.x, y: center.y - radius))
        context.addLine(to: CGPoint(x: center.x, y: center.y + radius))
        context.strokePath()
        context.restoreGState()

        context.saveGState()
        context.setStrokeColor(bright)
        context.setLineWidth(max(1, 10 * scale))
        context.strokeEllipse(in: globeRect)
        context.restoreGState()

        // Four readable nodes, each positioned outside dense globe geometry.
        let nodes = [
            CGPoint(x: center.x - 352 * scale, y: center.y + 172 * scale),
            CGPoint(x: center.x + 345 * scale, y: center.y + 116 * scale),
            CGPoint(x: center.x + 370 * scale, y: center.y - 206 * scale),
            CGPoint(x: center.x - 282 * scale, y: center.y - 202 * scale),
        ]
        for (index, point) in nodes.enumerated() {
            let nodeRadius = (index == 1 ? 18 : 14) * scale
            context.saveGState()
            context.setShadow(offset: .zero, blur: 18 * scale, color: glow)
            context.setFillColor(bright)
            context.fillEllipse(in: CGRect(
                x: point.x - nodeRadius,
                y: point.y - nodeRadius,
                width: nodeRadius * 2,
                height: nodeRadius * 2
            ))
            context.restoreGState()
        }
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

do {
    try NEXUSAppIconRenderer.run()
    print("Generated NEXUS AppIcon representations.")
} catch {
    fputs("AppIcon generation failed: \(error)\n", stderr)
    exit(EXIT_FAILURE)
}
