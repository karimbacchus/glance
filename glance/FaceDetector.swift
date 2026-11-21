//
//  FaceDetector.swift
//  glance
//
//  Converts Vision's normalized (0...1), bottom-left-origin face boxes into pixel-space, top-left-origin `CGRect`s.
//

import Vision
import CoreGraphics
import Foundation

nonisolated struct DetectedFace: Sendable {
    /// Pixel-space bounding box, top-left origin — ready to crop with.
    let boundingBox: CGRect
    /// Vision's original normalized box (bottom-left origin) — kept as-is since it's the exact format `layerRectConverted(fromMetadataOutputRect:)` expects.
    let normalizedBoundingBox: CGRect
    /// 0...1 confidence from Vision that this is a face, roughly indicating
    /// image quality/pose suitability for recognition. `nil` if the quality
    /// request didn't produce a result for this face.
    let quality: Float?
    /// Head rotation in radians, when Vision could estimate it. Yaw drives the guided-pose onboarding capture;
    /// roll and pitch are exposed but unused today.
    let yaw: Float?
    let roll: Float?
    let pitch: Float?
    /// Facial landmarks (eyes, nose, mouth, etc.) already in `imageSize` pixel space, top-left origin, when available.
    /// Feeds `FaceAligner` for canonical 112x112 alignment ahead of ArcFace.
    let landmarks: FaceLandmarks?
    let imageSize: CGSize
}

/// CPU-bound Vision work — `nonisolated` so it can run on a background task despite the project's default
/// main-actor isolation; `detectFaces` is additionally `@concurrent` so it never lands on a caller's actor.
nonisolated enum FaceDetector {
    /// Every request revision is pinned rather than left at Vision's default. Enrolled ArcFace templates are only
    /// comparable to live embeddings produced through the *same* landmark → alignment path, and the liveness geometry
    /// thresholds and capture-quality bands (`FaceSample.QualityTier`, onboarding's `qualityFloor`) are tuned against
    /// these exact models. An unpinned request follows whatever the OS considers the default, so a future OS shipping
    /// a newer face or landmark model must never silently shift alignment under every existing enrollment. Moving to
    /// a newer revision is a deliberate migration: validate match scores and liveness cues in Face Lab, then bump
    /// `ArcFaceEmbedder.modelIdentifier` so existing enrollments are flagged for recapture.
    ///
    /// Rectangles and landmarks use revision 4 and capture quality revision 3 (its latest). Revision 4 is reachable
    /// only through the Swift Vision API (`DetectFaceRectanglesRequest` & co.), not the legacy `VN*` classes.
    static let rectanglesRevision = DetectFaceRectanglesRequest.Revision.revision4
    static let landmarksRevision = DetectFaceLandmarksRequest.Revision.revision4
    static let captureQualityRevision = DetectFaceCaptureQualityRequest.Revision.revision3

    /// Runs face-rectangle, capture-quality, and landmarks detection on a single frame.
    @concurrent
    static func detectFaces(in image: CGImage) async throws -> [DetectedFace] {
        let handler = ImageRequestHandler(image)

        let faceObservations = try await handler.perform(DetectFaceRectanglesRequest(rectanglesRevision))
        guard !faceObservations.isEmpty else { return [] }

        // Chained to the rectangles results (via `inputFaceObservations`) rather than run independently, so results
        // correspond 1:1 in order — avoids the fragility of matching back via boundingBox float equality.
        var qualityRequest = DetectFaceCaptureQualityRequest(captureQualityRevision)
        qualityRequest.inputFaceObservations = faceObservations
        var landmarksRequest = DetectFaceLandmarksRequest(landmarksRevision)
        landmarksRequest.inputFaceObservations = faceObservations
        let (qualityResults, landmarkResults) = try await handler.perform(qualityRequest, landmarksRequest)

        let imageSize = CGSize(width: image.width, height: image.height)

        return faceObservations.enumerated().map { index, observation in
            let normalizedRect = observation.boundingBox.cgRect
            return DetectedFace(
                boundingBox: convertToImageSpace(normalizedRect, imageSize: imageSize),
                normalizedBoundingBox: normalizedRect,
                quality: qualityResults.indices.contains(index) ? qualityResults[index].captureQuality?.score : nil,
                yaw: radians(observation.yaw),
                roll: radians(observation.roll),
                pitch: radians(observation.pitch),
                landmarks: landmarkResults.indices.contains(index)
                    ? landmarkResults[index].landmarks.map { FaceLandmarks($0, imageSize: imageSize) }
                    : nil,
                imageSize: imageSize
            )
        }
    }

    /// Angles pass through with revision 4's own signs, which match the revision-3 convention the rest of the app —
    /// onboarding's guided poses in particular — was tuned against. Yaw is confirmed by a real guided enrollment: an
    /// earlier version negated yaw and roll on the strength of near-frontal test frames, and that inverted the
    /// left/right guidance. Pitch agreed in sign on live frames; roll is unused today.
    ///
    /// The Swift API exposes head angles as `Measurement<UnitAngle>`; the rest of the app works in radians. Non-finite
    /// values (no estimate) become `nil`, matching the optional the legacy API returned.
    private static func radians(_ angle: Measurement<UnitAngle>) -> Float? {
        let value = angle.converted(to: .radians).value
        return value.isFinite ? Float(value) : nil
    }

    /// Vision's normalized rect has origin at bottom-left; `CGImage.cropping`
    /// expects pixel coordinates with origin at top-left. This flips the Y axis.
    static func convertToImageSpace(_ normalizedRect: CGRect, imageSize: CGSize) -> CGRect {
        let x = normalizedRect.origin.x * imageSize.width
        let width = normalizedRect.width * imageSize.width
        let height = normalizedRect.height * imageSize.height
        let y = (1 - normalizedRect.origin.y) * imageSize.height - height
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Crops `face` out of `image`, padding slightly around the detected box
    /// so the embedder sees a bit of context beyond just eyes/nose/mouth.
    static func crop(_ face: DetectedFace, from image: CGImage, paddingFraction: CGFloat = 0.2) -> CGImage? {
        let imageBounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let padX = face.boundingBox.width * paddingFraction
        let padY = face.boundingBox.height * paddingFraction
        let padded = face.boundingBox.insetBy(dx: -padX, dy: -padY).intersection(imageBounds)
        guard !padded.isEmpty else { return nil }
        return image.cropping(to: padded)
    }
}

extension FaceLandmarks {
    /// Vision's region points → image-space pixels, top-left origin, y down.
    nonisolated init(_ landmarks: FaceObservation.Landmarks2D, imageSize: CGSize) {
        func points(_ region: FaceObservation.Landmarks2D.Region) -> [CGPoint] {
            region.pointsInImageCoordinates(imageSize, origin: .upperLeft)
        }
        self.init(
            leftEye: points(landmarks.leftEye), rightEye: points(landmarks.rightEye),
            leftPupil: points(landmarks.leftPupil), rightPupil: points(landmarks.rightPupil),
            leftEyebrow: points(landmarks.leftEyebrow), rightEyebrow: points(landmarks.rightEyebrow),
            nose: points(landmarks.nose), noseCrest: points(landmarks.noseCrest),
            outerLips: points(landmarks.outerLips), innerLips: points(landmarks.innerLips),
            faceContour: points(landmarks.faceContour), medianLine: points(landmarks.medianLine)
        )
    }
}
