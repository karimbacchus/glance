//
//  LowLightNormalizer.swift
//  glance
//
//  In a dark room the aligned face is dim and noisy, which degrades ArcFace badly (it was trained on well-exposed
//  faces). A cheap gamma lift on the 112x112 aligned image pulls the exposure back toward the enrollment range.
//

import CoreGraphics
import Foundation

nonisolated enum LowLightNormalizer {
    /// At or above this central mean luma (0...1) the image is returned untouched. Deliberately low: enrollments were
    /// captured in ordinary light with no normalization, so good-light embeddings must stay bit-identical to them.
    static let activationLuma: Float = 0.25
    /// Below this the frame is essentially black; brightening pure sensor noise doesn't help, so it's left alone.
    static let floorLuma: Float = 0.03
    /// Central mean luma the gamma lift aims for (roughly a normally exposed face).
    static let targetLuma: Float = 0.42
    /// Caps the lift so noise isn't amplified past the point of usefulness; 1.0 is identity.
    static let gammaRange: ClosedRange<Float> = 0.4...1.0

    /// `gain` is the gamma applied (nil when the image was returned untouched). Validate thresholds against real
    /// dark-room scans in Face Lab before tuning.
    static func normalize(_ image: CGImage) -> (image: CGImage, gain: Float?) {
        guard image.width > 0, image.height > 0,
              let colorSpace = image.colorSpace, colorSpace.model == .rgb,
              let context = CGContext(
                data: nil, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return (image, nil) }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let base = context.data else { return (image, nil) }

        let width = context.width, height = context.height, stride = context.bytesPerRow
        let pixels = base.assumingMemoryBound(to: UInt8.self)

        // Middle ~60% box: mostly skin, so hair and background don't bias the exposure estimate.
        let x0 = Int(Float(width) * 0.2), x1 = Int(Float(width) * 0.8)
        let y0 = Int(Float(height) * 0.2), y1 = Int(Float(height) * 0.8)
        guard x1 > x0, y1 > y0 else { return (image, nil) }

        var sum: Double = 0
        for y in y0..<y1 {
            let row = pixels + y * stride
            for x in x0..<x1 {
                let p = row + x * 4
                sum += 0.299 * Double(p[0]) + 0.587 * Double(p[1]) + 0.114 * Double(p[2])
            }
        }
        let mean = Float(sum / Double((x1 - x0) * (y1 - y0)) / 255)

        guard let gamma = gamma(forMeanLuma: mean) else { return (image, nil) }

        var lut = [UInt8](repeating: 0, count: 256)
        for i in 0..<256 {
            lut[i] = UInt8(min(255, max(0, (powf(Float(i) / 255, gamma) * 255).rounded())))
        }

        for y in 0..<height {
            let row = pixels + y * stride
            for x in 0..<width {
                let p = row + x * 4
                let a = Int(p[3])
                if a == 255 {
                    p[0] = lut[Int(p[0])]; p[1] = lut[Int(p[1])]; p[2] = lut[Int(p[2])]
                } else if a > 0 {
                    // Premultiplied edge pixel (outside the warp's source): lift the straight color, then re-premultiply.
                    for c in 0..<3 {
                        let straight = min(255, (Int(p[c]) * 255 + a / 2) / a)
                        p[c] = UInt8((Int(lut[straight]) * a + 127) / 255)
                    }
                }
            }
        }

        guard let output = context.makeImage() else { return (image, nil) }
        return (output, gamma)
    }

    /// nil means "don't touch". Pure so it can be sanity-checked in isolation.
    static func gamma(forMeanLuma mean: Float) -> Float? {
        guard mean < activationLuma, mean >= floorLuma else { return nil }
        let raw = logf(targetLuma) / logf(mean)
        return min(max(raw, gammaRange.lowerBound), gammaRange.upperBound)
    }
}
