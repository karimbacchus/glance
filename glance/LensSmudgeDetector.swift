//
//  LensSmudgeDetector.swift
//  glance
//
//  Advisory check for a smudged camera lens, using Vision's `DetectLensSmudgeRequest` (macOS 26+). A greasy lens —
//  on a MacBook, classically from the lid closing onto the keyboard — softens every frame, which lowers both capture
//  quality during enrollment and match similarity at unlock. This only ever produces a *hint*; it never gates an
//  unlock or blocks enrollment for longer than a short, bounded pause. On macOS 15 everything here is a no-op.
//
//  The model also scores ordinary blur highly (measured: a plain Gaussian blur of a sharp photo scores ~0.5–1.0, the
//  sharp original ~0.00), so a single soft frame from motion or refocusing means nothing. `LensSmudgeAssessment`
//  only raises the hint after several time-spaced samples agree, and only clears it once several agree it's gone.
//

import CoreGraphics
import Observation
import Vision

nonisolated enum LensSmudgeDetector {
    /// Whether this macOS ships the lens-smudge model at all.
    static var isSupported: Bool {
        if #available(macOS 26.0, *) { return true }
        return false
    }

    /// 0...1 likelihood the lens was smudged when `image` was captured; `nil` if unsupported or the request failed.
    /// `@concurrent` so the Vision work never lands on the caller's actor — callers are main-actor UI. The first call
    /// in a process also loads the model (~0.7s measured), which must not stall the main thread.
    @concurrent
    static func smudgeConfidence(in image: CGImage) async -> Float? {
        guard #available(macOS 26.0, *) else { return nil }
        return try? await DetectLensSmudgeRequest().perform(on: image).confidence
    }
}

/// Hysteresis over a short rolling window of per-frame smudge scores, so the hint neither fires on one motion-blurred
/// frame nor flickers while a borderline score wobbles. Pure value type — no Vision, no timing — so the rule is easy
/// to reason about and to exercise in isolation.
nonisolated struct LensSmudgeAssessment {
    /// Samples the decision looks at. With `LensSmudgeMonitor`'s default spacing this is roughly two seconds of
    /// consistent evidence either way.
    static let windowSize = 3
    /// Every sample in the window must reach this to raise the hint.
    static let raiseThreshold: Float = 0.8
    /// Every sample in the window must fall below this to clear it again. Scores in between keep the current state.
    static let clearThreshold: Float = 0.5

    private(set) var recentScores: [Float] = []
    private(set) var isSmudged = false

    mutating func record(_ score: Float) {
        recentScores.append(score)
        if recentScores.count > Self.windowSize {
            recentScores.removeFirst(recentScores.count - Self.windowSize)
        }
        guard recentScores.count == Self.windowSize else { return }
        if !isSmudged, recentScores.allSatisfy({ $0 >= Self.raiseThreshold }) {
            isSmudged = true
        } else if isSmudged, recentScores.allSatisfy({ $0 < Self.clearThreshold }) {
            isSmudged = false
        }
    }
}

/// Periodically scores the newest frame of a running `CameraManager` while started. Owned by whichever screen has the
/// camera on (Camera settings' preview, guided enrollment, Face Lab) — never by the lock-screen unlock path, which
/// shouldn't spend time or memory on a hint nobody is in a position to read.
@Observable
@MainActor
final class LensSmudgeMonitor {
    /// The debounced verdict UI should show — see `LensSmudgeAssessment`.
    private(set) var isSmudged = false
    /// The raw score of the most recent sample, for Face Lab's diagnostics.
    private(set) var latestScore: Float?

    @ObservationIgnored private var assessment = LensSmudgeAssessment()
    @ObservationIgnored private var samplingTask: Task<Void, Never>?

    /// Idempotent. Spacing samples out (rather than scoring every frame) is what lets the assessment tell a persistent
    /// smudge apart from a moment of motion blur, and keeps the cost negligible (~5ms per sample once warm).
    func start(sampling camera: CameraManager, every interval: Duration = .milliseconds(750)) {
        guard LensSmudgeDetector.isSupported, samplingTask == nil else { return }
        samplingTask = Task { [weak self, weak camera] in
            var lastScoredFrameID: UInt64?
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled, let self, let camera else { return }
                guard let frame = camera.currentFrame, frame.id != lastScoredFrameID else { continue }
                lastScoredFrameID = frame.id

                guard let score = await LensSmudgeDetector.smudgeConfidence(in: frame.image) else { continue }
                // Stopped (or restarted for another camera) while the request ran — don't let a stale score land.
                guard !Task.isCancelled else { return }
                self.record(score)
            }
        }
    }

    /// Stops sampling and forgets everything, so a restart (e.g. a different camera picked) starts from a clean slate.
    func stop() {
        samplingTask?.cancel()
        samplingTask = nil
        assessment = LensSmudgeAssessment()
        isSmudged = false
        latestScore = nil
    }

    private func record(_ score: Float) {
        latestScore = score
        assessment.record(score)
        if isSmudged != assessment.isSmudged {
            isSmudged = assessment.isSmudged
        }
    }
}
