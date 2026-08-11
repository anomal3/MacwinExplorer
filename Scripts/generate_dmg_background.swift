#!/usr/bin/swift
// Renders the background artwork for the installer DMG: a dark canvas with an
// arrow between the two icon slots and a short instruction line.
// Usage: swift generate_dmg_background.swift <output.png> [appDisplayName]

import AppKit

let arguments = CommandLine.arguments
guard arguments.count > 1 else {
    FileHandle.standardError.write("Usage: generate_dmg_background.swift <output.png> [appDisplayName]\n".data(using: .utf8)!)
    exit(1)
}
let outputPath = arguments[1]
let appName = arguments.count > 2 ? arguments[2] : "MacwinExplorer"

let size = NSSize(width: 660, height: 400)

// Render into a bitmap with pixel dimensions pinned to the logical size —
// otherwise lockFocus() on an NSImage picks up the host display's Retina
// backing scale and Finder (which treats PNG pixels as points, with no DPI
// awareness) would show the artwork at 2x the intended size.
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size.width),
    pixelsHigh: Int(size.height),
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

let gradient = NSGradient(
    starting: NSColor(calibratedRed: 0.20, green: 0.22, blue: 0.27, alpha: 1.0),
    ending: NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.11, alpha: 1.0)
)
gradient?.draw(in: NSRect(origin: .zero, size: size), angle: -90)

let arrowColor = NSColor(calibratedWhite: 1.0, alpha: 0.45)
let midY = size.height / 2 + 28
let arrowPath = NSBezierPath()
arrowPath.move(to: NSPoint(x: 270, y: midY))
arrowPath.line(to: NSPoint(x: 385, y: midY))
arrowPath.move(to: NSPoint(x: 385, y: midY))
arrowPath.line(to: NSPoint(x: 368, y: midY + 14))
arrowPath.move(to: NSPoint(x: 385, y: midY))
arrowPath.line(to: NSPoint(x: 368, y: midY - 14))
arrowPath.lineWidth = 4
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round
arrowColor.setStroke()
arrowPath.stroke()

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 17, weight: .medium),
    .foregroundColor: NSColor(calibratedWhite: 1.0, alpha: 0.9),
    .paragraphStyle: paragraph
]
let title = "Перетащите \(appName) в Applications, чтобы установить"
(title as NSString).draw(in: NSRect(x: 0, y: 55, width: size.width, height: 24), withAttributes: titleAttrs)

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("Failed to encode PNG\n".data(using: .utf8)!)
    exit(1)
}

do {
    try png.write(to: URL(fileURLWithPath: outputPath))
} catch {
    FileHandle.standardError.write("Failed to write \(outputPath): \(error)\n".data(using: .utf8)!)
    exit(1)
}
