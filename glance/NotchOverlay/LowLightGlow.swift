//
//  LowLightGlow.swift
//  glance
//
//  Warm-white edge glow for the lock screen. In a dark room the display is the only
//  light on the user's face and the lock screen is mostly black, so the camera sees
//  nothing; lighting the screen edges (like FaceTime's screen flash) fixes that
//  without touching system brightness. The center stays transparent so the login
//  UI remains readable. Reaches the lock screen via the same SkyLight space as the
//  notch overlay, ordered just below it.
//

import AppKit
import SwiftUI

/// Click-through, never-key panel covering one screen. Sits one level below
/// `NotchWindow` so the overlay always draws on top of the glow.
private final class LowLightGlowWindow: NSPanel {
    init(frame: NSRect) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        // Shielding level: highest public tier, directly under NotchWindow's shielding + 1.
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        ignoresMouseEvents = true
    }

    // Must never take focus or input away from the login window.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Inner edge glow: a thick stroke on the screen's edge, blurred so it fades to
/// nothing toward the center, and clipped so only the inward half shows.
private struct LowLightGlowView: View {
    let size: CGSize

    private static let cornerRadius: CGFloat = 14
    /// #FFF4E5 — warm white, kinder on the eyes than pure white at this brightness.
    private static let color = Color(red: 1.0, green: 244 / 255, blue: 229 / 255)

    var body: some View {
        let band = min(size.width, size.height) * 0.15
        RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
            .stroke(Self.color, lineWidth: band * 1.4)
            .blur(radius: band * 0.45)
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
            .allowsHitTesting(false)
    }
}

@MainActor
final class LowLightGlowController {
    private var window: LowLightGlowWindow?
    private var isSkyLightDelegated = false
    private var unlockObserver: NSObjectProtocol?
    /// Bumped on every request so a stale fade-out completion can't hide a newer fade-in.
    private var generation = 0

    private static let fadeInDuration: TimeInterval = 0.35
    private static let fadeOutDuration: TimeInterval = 0.4

    init() {
        // Backstop: if the coordinator never reports the unlock, don't leave a glow over the desktop.
        unlockObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.setActive(false, animated: false) }
        }
    }

    deinit {
        if let unlockObserver { DistributedNotificationCenter.default().removeObserver(unlockObserver) }
    }

    func setActive(_ active: Bool, animated: Bool = true) {
        generation += 1
        let token = generation
        if active { fadeIn() } else { fadeOut(animated: animated, token: token) }
    }

    private func fadeIn() {
        guard let screen = NotchGeometry.preferredScreen() else { return }
        let window = windowIfNeeded(for: screen)
        if window.frame != screen.frame { window.setFrame(screen.frame, display: false) }
        let alreadyShown = window.isVisible && window.alphaValue >= 1
        if !window.isVisible { window.alphaValue = 0 }
        window.orderFrontRegardless()

        if !isSkyLightDelegated, LockMonitor.isScreenActuallyLocked(), let skyLight = NotchSkyLight.shared {
            skyLight.delegate(window)
            isSkyLightDelegated = true
        }
        guard !alreadyShown else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeInDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
    }

    private func fadeOut(animated: Bool, token: Int) {
        guard let window, window.isVisible else { return }
        guard animated else { return tearDown() }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeOutDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.generation == token else { return }
                self.tearDown()
            }
        }
    }

    private func tearDown() {
        guard let window else { return }
        if isSkyLightDelegated, let skyLight = NotchSkyLight.shared {
            skyLight.undelegate(window)
            isSkyLightDelegated = false
        }
        window.orderOut(nil)
        window.alphaValue = 0
    }

    private func windowIfNeeded(for screen: NSScreen) -> LowLightGlowWindow {
        if let window { return window }
        let newWindow = LowLightGlowWindow(frame: screen.frame)
        let host = NSHostingView(rootView: LowLightGlowView(size: screen.frame.size))
        host.sizingOptions = []
        newWindow.contentView = host
        window = newWindow
        return newWindow
    }
}
