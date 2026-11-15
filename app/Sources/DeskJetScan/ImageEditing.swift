import AppKit
import CoreGraphics
import Foundation
import ImageIO

enum ImageEditing {
    /// Pixel width/height of the bitmap the UI and crop math share.
    static func pixelSize(of image: NSImage) -> CGSize {
        guard let cg = cgImage(from: image) else { return image.size }
        return CGSize(width: cg.width, height: cg.height)
    }

    /// One representation whose `size` matches its pixel buffer.
    static func normalized(_ image: NSImage) -> NSImage {
        guard let cg = cgImage(from: image) else { return image }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }

    static func rotate(_ image: NSImage, degrees: Int) -> NSImage? {
        guard let cg = cgImage(from: image) else { return nil }
        let radians = CGFloat(degrees) * .pi / 180
        let transform = CGAffineTransform(rotationAngle: radians)
        let bounds = CGRect(x: 0, y: 0, width: cg.width, height: cg.height).applying(transform)
        let outW = max(1, Int(abs(bounds.width).rounded()))
        let outH = max(1, Int(abs(bounds.height).rounded()))
        guard let context = CGContext(
            data: nil,
            width: outW,
            height: outH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.translateBy(x: CGFloat(outW) / 2, y: CGFloat(outH) / 2)
        context.rotate(by: radians)
        context.draw(cg, in: CGRect(
            x: -CGFloat(cg.width) / 2,
            y: -CGFloat(cg.height) / 2,
            width: CGFloat(cg.width),
            height: CGFloat(cg.height)
        ))
        guard let out = context.makeImage() else { return nil }
        return NSImage(cgImage: out, size: NSSize(width: out.width, height: out.height))
    }

    /// `normalized` is the crop in image space: origin at the **top-left**, axes 0…1.
    static func crop(_ image: NSImage, normalized: CGRect) -> NSImage? {
        guard let cg = cgImage(from: image) else { return nil }
        let pw = CGFloat(cg.width)
        let ph = CGFloat(cg.height)
        guard pw > 0, ph > 0 else { return nil }

        let minX = min(max(normalized.minX, 0), 1)
        let minY = min(max(normalized.minY, 0), 1)
        let maxX = min(max(normalized.maxX, 0), 1)
        let maxY = min(max(normalized.maxY, 0), 1)
        guard maxX - minX > 0.001, maxY - minY > 0.001 else { return nil }

        // Expand outward so the on-screen selection is never clipped inward.
        let x0 = floor(minX * pw)
        let y0Top = floor(minY * ph)
        let x1 = ceil(maxX * pw)
        let y1Top = ceil(maxY * ph)

        let width = max(1, min(pw, x1) - max(0, x0))
        let height = max(1, min(ph, y1Top) - max(0, y0Top))
        let x = max(0, x0)
        let yTop = max(0, y0Top)

        // CGImage origin is bottom-left; UI / SwiftUI origin is top-left.
        let cgRect = CGRect(x: x, y: ph - yTop - height, width: width, height: height)
            .integral
            .intersection(CGRect(x: 0, y: 0, width: pw, height: ph))
        guard cgRect.width >= 1, cgRect.height >= 1 else { return nil }

        // Draw instead of `cropping(to:)` so orientation stays identical to the preview.
        let outW = Int(cgRect.width)
        let outH = Int(cgRect.height)
        guard let context = CGContext(
            data: nil,
            width: outW,
            height: outH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(
            cg,
            in: CGRect(
                x: -cgRect.origin.x,
                y: -cgRect.origin.y,
                width: pw,
                height: ph
            )
        )
        guard let out = context.makeImage() else { return nil }
        return NSImage(cgImage: out, size: NSSize(width: out.width, height: out.height))
    }

    static func writePNG(_ image: NSImage, to url: URL) throws {
        guard let cg = cgImage(from: image) else {
            throw NSError(domain: "DeskJetScan", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Could not encode the image.",
            ])
        }
        let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
        guard let dest else {
            throw NSError(domain: "DeskJetScan", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Could not write \(url.lastPathComponent).",
            ])
        }
        CGImageDestinationAddImage(dest, cg, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw NSError(domain: "DeskJetScan", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "PNG write failed.",
            ])
        }
    }

    static func cgImage(from image: NSImage) -> CGImage? {
        let bitmaps = image.representations.compactMap { $0 as? NSBitmapImageRep }
        if let best = bitmaps.max(by: { $0.pixelsWide * $0.pixelsHigh < $1.pixelsWide * $1.pixelsHigh }),
           let cg = best.cgImage {
            return cg
        }
        var proposed = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &proposed, context: nil, hints: nil)
    }
}
