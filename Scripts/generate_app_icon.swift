#!/usr/bin/swift
// Renders the master 1024x1024 app icon: a Windows-Explorer-style yellow
// folder with a blue rectangle peeking out from behind, on a macOS-style
// rounded-square backdrop.
// Usage: swift generate_app_icon.swift <output.png>

import AppKit

let arguments = CommandLine.arguments
guard arguments.count > 1 else {
    FileHandle.standardError.write("Usage: generate_app_icon.swift <output.png>\n".data(using: .utf8)!)
    exit(1)
}
let outputPath = arguments[1]

let canvas = 1024
let size = NSSize(width: CGFloat(canvas), height: CGFloat(canvas))

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: canvas,
    pixelsHigh: canvas,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: rep) else {
    FileHandle.standardError.write("Failed to create bitmap context\n".data(using: .utf8)!)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
let cg = context.cgContext

// MARK: - Background (macOS-style rounded square)
let bgRect = NSRect(origin: .zero, size: size)
let bgRadius: CGFloat = CGFloat(canvas) * 0.225
let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: bgRadius, yRadius: bgRadius)
let bgGradient = NSGradient(
    starting: NSColor(calibratedRed: 0.90, green: 0.93, blue: 0.98, alpha: 1.0),
    ending: NSColor(calibratedRed: 0.78, green: 0.83, blue: 0.90, alpha: 1.0)
)
bgGradient?.draw(in: bgPath, angle: -90)

// MARK: - Blue rectangle peeking out from behind the folder
let blueRect = NSRect(x: 210, y: 108, width: 604, height: 400)
let bluePath = NSBezierPath(roundedRect: blueRect, xRadius: 30, yRadius: 30)
let blueGradient = NSGradient(
    starting: NSColor(calibratedRed: 0.24, green: 0.55, blue: 0.95, alpha: 1.0),
    ending: NSColor(calibratedRed: 0.08, green: 0.33, blue: 0.75, alpha: 1.0)
)
NSGraphicsContext.saveGraphicsState()
let blueShadow = NSShadow()
blueShadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
blueShadow.shadowBlurRadius = 18
blueShadow.shadowOffset = NSSize(width: 0, height: -8)
blueShadow.set()
blueGradient?.draw(in: bluePath, angle: -90)
NSGraphicsContext.restoreGraphicsState()

// A lighter glossy highlight near the top edge of the visible blue strip,
// so the peeking rectangle reads clearly instead of as a flat block.
let highlightRect = NSRect(x: 210, y: 168, width: 604, height: 30)
let highlightPath = NSBezierPath(roundedRect: highlightRect, xRadius: 8, yRadius: 8)
NSColor(calibratedRed: 0.55, green: 0.75, blue: 0.99, alpha: 0.8).setFill()
highlightPath.fill()

// MARK: - Yellow folder back panel
func folderBackPath() -> NSBezierPath {
    let path = NSBezierPath()
    let left: CGFloat = 150
    let right: CGFloat = 874
    let bottom: CGFloat = 260
    let top: CGFloat = 660
    let tabTop: CGFloat = 730
    let tabRight: CGFloat = 470
    let radius: CGFloat = 34

    path.move(to: NSPoint(x: left, y: bottom + radius))
    path.appendArc(withCenter: NSPoint(x: left + radius, y: bottom + radius), radius: radius, startAngle: 180, endAngle: 270)
    path.line(to: NSPoint(x: right - radius, y: bottom))
    path.appendArc(withCenter: NSPoint(x: right - radius, y: bottom + radius), radius: radius, startAngle: 270, endAngle: 360)
    path.line(to: NSPoint(x: right, y: top - radius))
    path.appendArc(withCenter: NSPoint(x: right - radius, y: top - radius), radius: radius, startAngle: 0, endAngle: 90)
    path.line(to: NSPoint(x: tabRight, y: top))
    path.line(to: NSPoint(x: tabRight - 55, y: tabTop))
    path.line(to: NSPoint(x: left + radius + 40, y: tabTop))
    path.appendArc(withCenter: NSPoint(x: left + radius + 40, y: tabTop - radius), radius: radius, startAngle: 90, endAngle: 180)
    path.line(to: NSPoint(x: left, y: bottom + radius))
    path.close()
    return path
}

let backPath = folderBackPath()
NSGraphicsContext.saveGraphicsState()
let folderShadow = NSShadow()
folderShadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
folderShadow.shadowBlurRadius = 22
folderShadow.shadowOffset = NSSize(width: 0, height: -10)
folderShadow.set()
let backGradient = NSGradient(
    starting: NSColor(calibratedRed: 1.0, green: 0.80, blue: 0.30, alpha: 1.0),
    ending: NSColor(calibratedRed: 0.98, green: 0.68, blue: 0.10, alpha: 1.0)
)
backGradient?.draw(in: backPath, angle: -90)
NSGraphicsContext.restoreGraphicsState()

// MARK: - Yellow folder front flap (brighter, layered on top)
func folderFrontPath() -> NSBezierPath {
    let path = NSBezierPath()
    let left: CGFloat = 118
    let right: CGFloat = 906
    let bottom: CGFloat = 200
    let top: CGFloat = 470
    let radius: CGFloat = 34

    path.move(to: NSPoint(x: left, y: bottom + radius))
    path.appendArc(withCenter: NSPoint(x: left + radius, y: bottom + radius), radius: radius, startAngle: 180, endAngle: 270)
    path.line(to: NSPoint(x: right - radius, y: bottom))
    path.appendArc(withCenter: NSPoint(x: right - radius, y: bottom + radius), radius: radius, startAngle: 270, endAngle: 360)
    path.line(to: NSPoint(x: right, y: top - radius))
    path.appendArc(withCenter: NSPoint(x: right - radius, y: top - radius), radius: radius, startAngle: 0, endAngle: 90)
    path.line(to: NSPoint(x: left + radius, y: top))
    path.appendArc(withCenter: NSPoint(x: left + radius, y: top - radius), radius: radius, startAngle: 90, endAngle: 180)
    path.close()
    return path
}

let frontPath = folderFrontPath()
NSGraphicsContext.saveGraphicsState()
let frontShadow = NSShadow()
frontShadow.shadowColor = NSColor.black.withAlphaComponent(0.20)
frontShadow.shadowBlurRadius = 14
frontShadow.shadowOffset = NSSize(width: 0, height: -6)
frontShadow.set()
let frontGradient = NSGradient(
    starting: NSColor(calibratedRed: 1.0, green: 0.86, blue: 0.42, alpha: 1.0),
    ending: NSColor(calibratedRed: 1.0, green: 0.73, blue: 0.16, alpha: 1.0)
)
frontGradient?.draw(in: frontPath, angle: -90)
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("Failed to encode PNG\n".data(using: .utf8)!)
    exit(1)
}

do {
    try png.write(to: URL(fileURLWithPath: outputPath))
    print("Wrote \(outputPath)")
} catch {
    FileHandle.standardError.write("Failed to write \(outputPath): \(error)\n".data(using: .utf8)!)
    exit(1)
}
