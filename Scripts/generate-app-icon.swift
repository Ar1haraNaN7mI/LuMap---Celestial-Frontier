#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

private let designSize: CGFloat = 1024
private let outputSizes = [16, 32, 64, 128, 256, 512, 1024]

private func color(
    _ red: CGFloat,
    _ green: CGFloat,
    _ blue: CGFloat,
    _ alpha: CGFloat = 1
) -> CGColor {
    CGColor(
        colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        components: [red / 255, green / 255, blue / 255, alpha]
    )!
}

private func sparklePath(
    center: CGPoint,
    horizontalRadius: CGFloat,
    verticalRadius: CGFloat,
    waist: CGFloat
) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: center.x, y: center.y + verticalRadius))
    path.addCurve(
        to: CGPoint(x: center.x + horizontalRadius, y: center.y),
        control1: CGPoint(x: center.x + waist * 0.22, y: center.y + waist * 1.35),
        control2: CGPoint(x: center.x + waist * 1.35, y: center.y + waist * 0.22)
    )
    path.addCurve(
        to: CGPoint(x: center.x, y: center.y - verticalRadius),
        control1: CGPoint(x: center.x + waist * 1.35, y: center.y - waist * 0.22),
        control2: CGPoint(x: center.x + waist * 0.22, y: center.y - waist * 1.35)
    )
    path.addCurve(
        to: CGPoint(x: center.x - horizontalRadius, y: center.y),
        control1: CGPoint(x: center.x - waist * 0.22, y: center.y - waist * 1.35),
        control2: CGPoint(x: center.x - waist * 1.35, y: center.y - waist * 0.22)
    )
    path.addCurve(
        to: CGPoint(x: center.x, y: center.y + verticalRadius),
        control1: CGPoint(x: center.x - waist * 1.35, y: center.y + waist * 0.22),
        control2: CGPoint(x: center.x - waist * 0.22, y: center.y + waist * 1.35)
    )
    path.closeSubpath()
    return path
}

private func drawIcon(in context: CGContext, pixelSize: Int) {
    let scale = CGFloat(pixelSize) / designSize
    context.scaleBy(x: scale, y: scale)
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    let tile = CGRect(x: 74, y: 78, width: 876, height: 876)
    let tilePath = CGPath(
        roundedRect: tile,
        cornerWidth: 198,
        cornerHeight: 198,
        transform: nil
    )

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -24), blur: 42, color: color(25, 19, 72, 0.34))
    context.addPath(tilePath)
    context.setFillColor(color(76, 55, 212))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(tilePath)
    context.clip()

    let backgroundGradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [color(82, 62, 221), color(110, 89, 242), color(41, 171, 212)] as CFArray,
        locations: [0, 0.44, 1]
    )!
    context.drawLinearGradient(
        backgroundGradient,
        start: CGPoint(x: 170, y: 150),
        end: CGPoint(x: 890, y: 900),
        options: []
    )

    let cyanGlow = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [color(255, 255, 255, 0.28), color(255, 255, 255, 0)] as CFArray,
        locations: [0, 1]
    )!
    context.drawRadialGradient(
        cyanGlow,
        startCenter: CGPoint(x: 788, y: 824),
        startRadius: 0,
        endCenter: CGPoint(x: 788, y: 824),
        endRadius: 470,
        options: [.drawsAfterEndLocation]
    )

    context.setBlendMode(.softLight)
    context.setStrokeColor(color(255, 255, 255, 0.18))
    context.setLineWidth(18)
    context.addArc(
        center: CGPoint(x: 504, y: 510),
        radius: 326,
        startAngle: .pi * 0.10,
        endAngle: .pi * 0.63,
        clockwise: false
    )
    context.strokePath()
    context.setStrokeColor(color(255, 255, 255, 0.11))
    context.setLineWidth(11)
    context.addArc(
        center: CGPoint(x: 504, y: 510),
        radius: 260,
        startAngle: .pi * 1.03,
        endAngle: .pi * 1.54,
        clockwise: false
    )
    context.strokePath()
    context.restoreGState()

    let mainSparkle = sparklePath(
        center: CGPoint(x: 508, y: 510),
        horizontalRadius: 210,
        verticalRadius: 248,
        waist: 62
    )
    context.saveGState()
    context.setShadow(offset: .zero, blur: 56, color: color(255, 255, 255, 0.56))
    context.addPath(mainSparkle)
    context.setFillColor(color(255, 255, 255))
    context.fillPath()
    context.restoreGState()

    let smallSparkle = sparklePath(
        center: CGPoint(x: 742, y: 746),
        horizontalRadius: 54,
        verticalRadius: 68,
        waist: 18
    )
    context.saveGState()
    context.setShadow(offset: .zero, blur: 24, color: color(255, 255, 255, 0.42))
    context.addPath(smallSparkle)
    context.setFillColor(color(255, 255, 255, 0.94))
    context.fillPath()
    context.restoreGState()

    context.setFillColor(color(255, 255, 255, 0.76))
    context.fillEllipse(in: CGRect(x: 306, y: 316, width: 34, height: 34))

    context.saveGState()
    context.addPath(tilePath)
    context.setStrokeColor(color(255, 255, 255, 0.18))
    context.setLineWidth(4)
    context.strokePath()
    context.restoreGState()
}

private func render(size: Int, to url: URL) throws {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }

    drawIcon(in: context, pixelSize: size)
    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(
              url as CFURL,
              UTType.png.identifier as CFString,
              1,
              nil
          ) else {
        throw CocoaError(.fileWriteUnknown)
    }

    CGImageDestinationAddImage(destination, image, [
        kCGImagePropertyPNGDictionary: [
            kCGImagePropertyPNGInterlaceType: 0
        ]
    ] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        throw CocoaError(.fileWriteUnknown)
    }
}

let scriptURL = URL(fileURLWithPath: #filePath).standardizedFileURL
let projectRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let outputDirectory = projectRoot
    .appendingPathComponent("Lumap", isDirectory: true)
    .appendingPathComponent("Assets.xcassets", isDirectory: true)
    .appendingPathComponent("AppIcon.appiconset", isDirectory: true)

try FileManager.default.createDirectory(
    at: outputDirectory,
    withIntermediateDirectories: true
)

for size in outputSizes {
    let outputURL = outputDirectory.appendingPathComponent("AppIcon-\(size).png")
    try render(size: size, to: outputURL)
    print("Generated \(outputURL.path)")
}
