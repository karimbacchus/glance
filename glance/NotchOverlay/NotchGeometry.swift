//
//  NotchGeometry.swift
//  glance
//
//  Pure geometry — no AppKit window knowledge.
//

import AppKit
import CoreGraphics

struct NotchGeometry {
    /// The hardware cutout's own dimensions (notch or island), or `pillClosedSize` on a display with neither.
    let closedSize: CGSize
    let style: NotchPanelStyle

    /// Distance from the screen's top edge to the top of the resting silhouette. The pill's slide-in animates away
    /// from this.
    var closedTopInset: CGFloat {
        switch style {
        case .notch: return 0
        case .island: return Self.islandTopInset
        case .pill: return Self.pillTopGap
        }
    }

    /// Island style, minimal scans: how far the capsule's center sits from the island's center (negative = left).
    /// Docked on the left, `islandSiblingGap` clear of macOS's camera-in-use capsule — or, when the camera is off
    /// (Settings' animation preview), of the bare island. Zero for every other style, which grow in place.
    func islandExpandedCenterOffset(panelWidth: CGFloat, besideCameraIndicator: Bool) -> CGFloat {
        guard style == .island else { return 0 }
        let clearance = besideCameraIndicator ? Self.islandCameraIndicatorLeadingExtent : closedSize.width / 2
        return -(clearance + Self.islandSiblingGap + panelWidth / 2)
    }

    /// Island style, original scans: the expanded square's top edge — just below the island's band, centered under
    /// it, clear of the camera-in-use activity macOS fills the band with while the camera runs.
    var islandBelowTopInset: CGFloat {
        closedTopInset + closedSize.height + Self.islandDropGap
    }

    /// Fixed footprint of expanded scan-mode content in notch style. Sized for the
    /// square (432x432) scan animation plus breathing room. Pill has its own `pillOpenSize`.
    static let notchOpenSize = CGSize(width: 220, height: 200)

    /// Corner radii for the notch silhouette. The top radius doubles as the
    /// width of the outward flare on each side (see NotchShape).
    static let closedTopRadius: CGFloat = 8
    static let closedBottomRadius: CGFloat = 12
    static let openTopRadius: CGFloat = 16
    static let openBottomRadius: CGFloat = 60

    /// A shape drawn in a rect of width `w` has a visible body of `w - 2 * topRadius`;
    /// zero in pill style, which has no flare.
    static func flareAllowance(topRadius: CGFloat, style: NotchPanelStyle) -> CGFloat {
        style == .notch ? topRadius * 2 : 0
    }

    // MARK: - Island style (Dynamic Island displays) — EDIT HERE
    //
    // The PROLED XDR MacBook Pro replaces the notch with a hole-punch camera: a capsule floating just below the top
    // edge, with display pixels all around it. macOS publishes only the rectangle it reserves for it — the gap between
    // `auxiliaryTopLeftArea` and `auxiliaryTopRightArea`, `safeAreaInsets.top` tall and flush with the top edge (59 x 40pt
    // on a 16" Mac17,12) — not the capsule itself. Its shape below was measured from what the system paints into the
    // framebuffer behind the cutout on that machine: the reserved rect's full width, from ~8.5pt below the top edge down
    // to the bottom of the reserved band (a 31pt-tall stadium). Each value is rounded outward by half a point so the
    // overlay's resting capsule fully covers the hardware's anti-aliased edge.

    /// Gap between the screen's top edge and the top of the island. The island's height is the reserved band's height
    /// minus this.
    static let islandTopInset: CGFloat = 8

    /// A cutout narrower than this multiple of its reserved band's height is a hole-punch island, not a notch: notches
    /// are several times wider than tall (~180–200 x 32–38pt), the island barely wider than tall (59 x 40pt).
    static let islandMaxAspectRatio: CGFloat = 3

    // Clear of the camera indicator. A scan always has the camera on, and on these displays macOS then turns the
    // island into its own camera-in-use activity: the capsule widens (green dot and camera glyph on its trailing side)
    // and, depending on what else is running, a live-preview bubble or another activity (music, say) appears on the
    // right. All of it is composited above every app window — deliberately, so no app can hide camera use — and none
    // of it is exposed as a window or API an app could measure. So a scan never grows over the island:
    //  - Minimal docks *beside* it, the way macOS slots its own activities — on the left, the side the system keeps
    //    free. Across the states observed (camera alone; camera + music) the capsule's leading end sat 65.5–68.5pt
    //    left of the island's center, while its trailing side moved around.
    //  - Original's square is too big for the island's row, so it hangs just below the band instead.

    /// How far left of the island's center macOS's camera-in-use capsule reaches (measured 65.5–68.5pt).
    static let islandCameraIndicatorLeadingExtent: CGFloat = 69
    /// Space between Glance's element and whatever it docks beside — the gap macOS itself leaves between its capsule
    /// and the preview bubble (9pt).
    static let islandSiblingGap: CGFloat = 9

    /// Gap between the bottom of the island's band and the original style's square hanging below it — far enough
    /// that the two read as separate shapes, close enough to read as related.
    static let islandDropGap: CGFloat = 5
    /// Original style, hanging below the island: a rounded square, like Face ID on iPhone.
    static let islandOpenSize = CGSize(width: 180, height: 180)
    static let islandOpenCornerRadius: CGFloat = 46
    /// Uniform scan-content inset — the camera is never inside the expanded panel.
    static let islandContentPadding: CGFloat = 32

    /// Minimal style, docked beside the island: a compact capsule at the island's own height — lock glyph and
    /// animation — mirroring the system's preview bubble on the other side. `islandMinimalEdgeInset + 2 *
    /// islandMinimalMediaWidth` must fit inside `islandMinimalWidth` with room to spare.
    static let islandMinimalWidth: CGFloat = 76
    static let islandMinimalEdgeInset: CGFloat = 8
    static let islandMinimalLockIconSize: CGFloat = 12
    static let islandMinimalMediaWidth: CGFloat = 24
    static let islandMinimalMediaVerticalInset: CGFloat = 6

    static let islandShadowPadding: CGFloat = 24

    // MARK: - Pill style (non-notched displays) — EDIT HERE
    //
    // The dynamic-island fallback. Collapsed it's a capsule; expanded it's a
    // floating rounded rectangle sized by `pillOpenSize` in scan mode, or
    // whatever step onboarding is on.

    /// Deliberately narrower than every expanded footprint so growth reads as visible.
    static let pillClosedSize = CGSize(width: 80, height: 24)

    /// Independent of `notchOpenSize`; larger by default since the pill has no camera housing.
    static let pillOpenSize = CGSize(width: 180, height: 180)

    /// Never zero — the whole point of the pill is that it's detached from the edge.
    static let pillTopGap: CGFloat = 3

    /// Uniform on all four corners (unlike the notch); matches `openBottomRadius`.
    static let pillOpenCornerRadius: CGFloat = 48

    /// Blur applied to the whole panel while off-screen, resolving to zero as it slides into place.
    static let pillEnterBlur: CGFloat = 0

    /// Comfortably more than `pillEnterBlur` — a Gaussian blur spreads past its nominal
    /// radius, and without this margin the parked pill smears a faint band at the screen top.
    static let pillOffscreenSlack: CGFloat = 20

    /// Pill's equivalent of `notchContentPadding*` below, independent so it can be tuned separately.
    static let pillContentPaddingTop: CGFloat = 32
    static let pillContentPaddingLeading: CGFloat = 32
    static let pillContentPaddingTrailing: CGFloat = 32
    static let pillContentPaddingBottom: CGFloat = 32

    // MARK: - Panel open/close springs — EDIT HERE
    //
    // Shared by both styles. Opening overshoots slightly; closing is critically damped.
    static let openSpringResponse: Double = 0.45
    static let openSpringDamping: Double = 0.7
    static let closeSpringResponse: Double = 0.45
    static let closeSpringDamping: Double = 1.0

    // MARK: - Pill enter/exit choreography — EDIT HERE
    //
    // Style `.pill` only. Slide and expansion run on independent timelines:
    // enter slides first then grows; exit shrinks first then slides away.

    /// Ease-out rather than a spring — a straight-line move, not a bouncy resize.
    static let pillSlideDuration: Double = 0.25
    /// Expansion starts this long after the slide begins.
    static let pillEnterExpansionDelay: Double = 0.16
    /// Slide starts this long after the shrink begins.
    static let pillExitSlideDelay: Double = 0.18

    // MARK: - Minimal unlock style — EDIT HERE
    //
    // `UnlockAnimationStyle.minimal`: the silhouette widens only, revealing a lock
    // icon on one side and the unlock video on the other. See MinimalUnlockView.

    /// Total notch body width is `geometry.closedSize.width + 2 * this`. Window is
    /// ~434pt wide (see `windowSize(for:)`), so much past 100 will start to clip.
    static let minimalNotchFlankWidth: CGFloat = 42

    /// Taller than `pillClosedSize.height` for legibility; radius stays `height / 2`
    /// so it remains a true capsule while stretching.
    static let minimalPillOpenWidth: CGFloat = 150
    static let minimalPillOpenHeight: CGFloat = 40

    /// Extra height added only in notch style — the physical notch's height can't
    /// change, so this appears as real, visible black below it.
    static let minimalNotchHeightBump: CGFloat = 12

    /// More rounded than the resting silhouette's radii (8/12), same ratio the
    /// full-expand style uses (16/60).
    static let minimalNotchTopRadius: CGFloat = 12
    static let minimalNotchBottomRadius: CGFloat = 22

    /// In notch style the flare already occupies `topRadius` of this margin.
    static let minimalContentEdgeInset: CGFloat = 4

    /// Point size of the lock glyph, pill style (and the shared fallback).
    static let minimalLockIconSize: CGFloat = 14
    /// The video is square and aspect-fit, so its rendered size is really
    /// `min(this, panelHeight - 2 * minimalMediaVerticalInset)`.
    static let minimalMediaWidth: CGFloat = 34
    /// Without this the square aspect-fits to the full panel height and touches both edges.
    static let minimalMediaVerticalInset: CGFloat = 8

    /// Notch-style counterparts of the three above, bumped up to match `minimalNotchHeightBump`.
    static let minimalNotchLockIconSize: CGFloat = 16
    static let minimalNotchMediaWidth: CGFloat = 40
    static let minimalNotchMediaVerticalInset: CGFloat = 11

    /// So the lock glyph can be nudged to land with the video's own resolve beat.
    static let minimalLockUnlockDelay: Double = 0
    static let minimalLockAnimationDuration: Double = 0.4

    // MARK: - Scan "breathing" pulse — EDIT HERE
    //
    // While `.scanning`, content ping-pongs between full size/opacity and
    // `scanPulseScale`/`scanPulseOpacity` so the panel reads as searching, not frozen.
    // See `NotchOverlayView.startScanPulse()`.

    /// Scale at the dimmed end of the ping-pong. 1.0 disables the size part.
    static let scanPulseScale: CGFloat = 0.97
    /// Opacity at the dimmed end. 1.0 disables the fade part.
    static let scanPulseOpacity: Double = 0.65
    /// One half-cycle — full → dimmed, or dimmed → full.
    static let scanPulseHalfCycleDuration: Double = 0.4
    /// Pause at each end before reversing. 0 makes it a continuous breathe.
    static let scanPulseHoldDuration: Double = 0.05
    /// Deliberately quicker than a half-cycle so content is back at full while the
    /// success/failure animation is still early in its playback.
    static let scanPulseSettleDuration: Double = 0.2

    /// Wait before the first pulse cycle so breathing starts only once the panel has
    /// finished expanding. Hand-tuned approximation — springs have no hard end time.
    static let scanPulseStartDelay: Double = 0.6

    /// Notch-style padding around scan-mode content. Pill has its own independent set below.
    static let notchContentPaddingTop: CGFloat = 26
    static let notchContentPaddingLeading: CGFloat = 40
    static let notchContentPaddingTrailing: CGFloat = 40
    static let notchContentPaddingBottom: CGFloat = 30

    /// Cosmetic size bump applied on hover in NotchOverlayView. Included here so the
    /// fixed window has margin for it instead of clipping.
    static let hoverBump: CGFloat = 6

    // MARK: - Window size, per style — EDIT HERE
    //
    // Created once and never resized afterward (see NotchWindow.swift). Each style is
    // floored to its own scan-mode footprint and gets its own shadow margin, tuned independently.

    /// Extra margin so SwiftUI's `.shadow()` isn't clipped (the window itself has
    /// `hasShadow = false` — the shadow is drawn in-content).
    static let notchShadowPadding: CGFloat = 24
    static let pillShadowPadding: CGFloat = 24

    static func windowSize(for geometry: NotchGeometry) -> CGSize {
        switch geometry.style {
        case .notch:
            let contentWidth = max(notchOpenSize.width, OnboardingMetrics.maxPanelWidth)
            let contentHeight = max(notchOpenSize.height, OnboardingMetrics.maxPanelHeight(for: .notch))
            return CGSize(
                width: contentWidth + notchShadowPadding * 2 + hoverBump,
                height: contentHeight + notchShadowPadding + hoverBump
            )
        case .island:
            // Centered on the island, so each half must reach the farthest of onboarding's edge, the minimal capsule
            // docked left of the camera indicator, and the original square hanging below the island.
            let dockedReach = islandCameraIndicatorLeadingExtent + islandSiblingGap + islandMinimalWidth + hoverBump
            let halfWidth = max(OnboardingMetrics.maxPanelWidth / 2, dockedReach, (islandOpenSize.width + hoverBump) / 2)
                + islandShadowPadding
            let bottom = max(
                geometry.closedTopInset + OnboardingMetrics.maxPanelHeight(for: .island),
                geometry.islandBelowTopInset + islandOpenSize.height
            )
            return CGSize(width: halfWidth * 2, height: bottom + islandShadowPadding + hoverBump)
        case .pill:
            let contentWidth = max(pillOpenSize.width, OnboardingMetrics.maxPanelWidth)
            let contentHeight = max(pillOpenSize.height, OnboardingMetrics.maxPanelHeight(for: .pill))
            return CGSize(
                width: contentWidth + pillShadowPadding * 2 + hoverBump,
                // `pillTopGap` since the detached pill's panel is pushed down by that much.
                height: contentHeight + pillShadowPadding + hoverBump + pillTopGap
            )
        }
    }

    static func forMainScreen() -> NotchGeometry {
        guard let screen = NSScreen.main else {
            return NotchGeometry(closedSize: pillClosedSize, style: .pill)
        }
        return forScreen(screen)
    }

    static func forScreen(_ screen: NSScreen) -> NotchGeometry {
        guard screen.safeAreaInsets.top > 0 else {
            return NotchGeometry(closedSize: pillClosedSize, style: .pill)
        }

        // Width derived from the menu-bar areas flanking the notch — nil/empty on
        // displays without one, hence the safeAreaInsets check above.
        let leftPadding = screen.auxiliaryTopLeftArea?.width ?? 0
        let rightPadding = screen.auxiliaryTopRightArea?.width ?? 0
        // These are all AppKit point values. Do not impose a model-derived minimum:
        // the camera housing on a 13-inch MacBook Air is legitimately narrower than
        // the 200-point housing on several MacBook Pro models.
        let width = screen.frame.width - leftPadding - rightPadding
        let height = screen.safeAreaInsets.top

        // Both a notch and an island reserve a flush-with-the-top rectangle; only its proportions tell them apart.
        if width < height * islandMaxAspectRatio, height > islandTopInset {
            return NotchGeometry(
                closedSize: CGSize(width: width, height: height - islandTopInset),
                style: .island
            )
        }
        return NotchGeometry(closedSize: CGSize(width: width, height: height), style: .notch)
    }

    /// Picks the screen the overlay should show on. If a display is pinned
    /// (`GlanceSettings.preferredDisplayID`), it's used only if still connected — no
    /// fallback. Otherwise: the display with a camera cutout (notch or island) if any, else the primary screen.
    @MainActor
    static func preferredScreen() -> NSScreen? {
        if let targetID = GlanceSettings.shared.preferredDisplayID {
            return NSScreen.screens.first { $0.stableDisplayID == targetID }
        }
        return NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }
}

extension NSScreen {
    /// Stable enough to persist a user's display choice across launches — the only
    /// per-display identity AppKit exposes.
    var stableDisplayID: String? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return nil
        }
        return String(number)
    }

    /// True for the Mac's own display (vs. an external monitor) — used to pin the Face
    /// Unlock panel there while the built-in camera is selected.
    var isBuiltIn: Bool {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return false
        }
        return CGDisplayIsBuiltin(number) != 0
    }
}
