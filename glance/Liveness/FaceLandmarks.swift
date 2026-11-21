//
//  FaceLandmarks.swift
//  glance
//
//  Vision-free landmark container: `FaceDetector` converts Vision's per-region normalized points into this once, so
//  `FaceAligner`, `LandmarkGeometry` and the liveness extractor never touch Vision types. Kept free of `import Vision`
//  so `tools/liveness_selftest.swift` can compile it alongside `LandmarkGeometry`.
//

import CoreGraphics

/// Every landmark region this app reads, as image-space points: pixels of the detected image, top-left origin,
/// y pointing down (the same space as `DetectedFace.boundingBox`). A region Vision didn't produce is empty.
///
/// `leftEye`/`rightEye` (and the pupils, eyebrows) follow Vision's labelling, which is anatomical rather than
/// on-screen — callers that need image-left/right must sort by x, as `FaceAligner` does.
nonisolated struct FaceLandmarks: Sendable, Equatable {
    var leftEye: [CGPoint] = []
    var rightEye: [CGPoint] = []
    var leftPupil: [CGPoint] = []
    var rightPupil: [CGPoint] = []
    var leftEyebrow: [CGPoint] = []
    var rightEyebrow: [CGPoint] = []
    var nose: [CGPoint] = []
    var noseCrest: [CGPoint] = []
    var outerLips: [CGPoint] = []
    var innerLips: [CGPoint] = []
    var faceContour: [CGPoint] = []
    var medianLine: [CGPoint] = []

    /// Points of one of the liveness-sampled regions.
    func points(for region: LandmarkRegion) -> [CGPoint] {
        switch region {
        case .leftEye: return leftEye
        case .rightEye: return rightEye
        case .leftEyebrow: return leftEyebrow
        case .rightEyebrow: return rightEyebrow
        case .nose: return nose
        case .noseCrest: return noseCrest
        case .outerLips: return outerLips
        case .innerLips: return innerLips
        case .faceContour: return faceContour
        case .medianLine: return medianLine
        }
    }
}
