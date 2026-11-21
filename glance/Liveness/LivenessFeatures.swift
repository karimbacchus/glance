//
//  LivenessFeatures.swift
//  glance
//
//  Vision-facing half of liveness: turns a `FaceRecognitionResult` into a plain,
//  Vision-free `LivenessFrame` — keeps the decision logic compilable standalone.
//

import CoreGraphics
import Foundation

nonisolated enum LivenessFeatureExtractor {
    /// Never fails — a face with no landmarks still yields a frame; cues that need landmarks abstain.
    ///
    /// - Parameter frame: the full camera frame, not `result.alignedImage` (a tightly-cropped
    ///   112x112 warp with no room around the face for `DeviceBezelDetector` to see a device edge).
    static func extract(
        from result: FaceRecognitionResult, frame: CGImage, faceCrop: CGImage? = nil, timestamp: Date = Date()
    ) -> LivenessFrame {
        let face = result.face
        let deviceOverlap = DeviceBezelDetector.detect(in: frame, faceBoundingBox: face.boundingBox).faceOverlapFraction
        let glare = faceCrop.flatMap { GlareCueExtractor.extract(faceCrop: $0) }

        guard let landmarks = face.landmarks else {
            return LivenessFrame(
                timestamp: timestamp, landmarks: [], interocularDistance: nil,
                yaw: face.yaw,
                leftEyeAspectRatio: nil, rightEyeAspectRatio: nil,
                noseOffsetRatio: nil,
                hasReliableLandmarks: false,
                deviceOverlapFraction: deviceOverlap,
                glare: glare
            )
        }

        let points = LandmarkGeometry.allPoints(from: landmarks)
        let interocular = LandmarkGeometry.interocularDistance(from: landmarks)
        let leftEAR = LandmarkGeometry.eyeAspectRatio(of: landmarks.leftEye)
        let rightEAR = LandmarkGeometry.eyeAspectRatio(of: landmarks.rightEye)

        let eyeLeft = LandmarkGeometry.eyeCenter(pupil: landmarks.leftPupil, eye: landmarks.leftEye)
        let eyeRight = LandmarkGeometry.eyeCenter(pupil: landmarks.rightPupil, eye: landmarks.rightEye)

        var noseOffsetRatio: CGFloat?
        if let interocular, interocular > 0, let eyeLeft, let eyeRight,
           let noseCenter = LandmarkGeometry.centroid(of: landmarks.nose) {
            let eyeMidX = (eyeLeft.x + eyeRight.x) / 2
            noseOffsetRatio = (noseCenter.x - eyeMidX) / interocular
        }

        return LivenessFrame(
            timestamp: timestamp,
            landmarks: points,
            interocularDistance: interocular,
            yaw: face.yaw,
            leftEyeAspectRatio: leftEAR, rightEyeAspectRatio: rightEAR,
            noseOffsetRatio: noseOffsetRatio,
            hasReliableLandmarks: result.alignmentTier == .fivePoint,
            deviceOverlapFraction: deviceOverlap,
            glare: glare
        )
    }
}
