//
//  ProgressiveHeaderBlur.swift
//  glance
//
//  A backdrop blur behind the header whose strength fades from strongest at
//  the window's top edge to none by the bottom of the blur zone, so
//  scrolled rows sharpen up as they pass underneath rather than cutting
//  from blurred to crisp at a hard line.
//
//  Used on every macOS version. macOS 26's `safeAreaBar` +
//  `scrollEdgeEffectStyle` is the system's version of this, but compared
//  side by side on macOS 27 `.soft` barely softened rows passing the traffic
//  lights and `.hard` turned the floating header into an opaque strip (see
//  `SettingsWindowView.contentPage`). So this does it manually: each `Material` (weakest
//  to strongest) is masked to fade out over a shorter distance than the
//  last, so only a thin band right at the top ever stacks every layer —
//  the same layered-mask trick most manual "progressive blur" implementations
//  use, since `.blur(radius:)` itself has no per-pixel-varying radius.
//

import SwiftUI

struct ProgressiveHeaderBlur: View {
    var height: CGFloat
    /// Which edge the blur is strongest at. `.bottom` mirrors it for the
    /// floating tab bar (see `SettingsWindowView.contentPage`).
    var edge: VerticalEdge = .top

    /// Weakest to strongest. The weakest spans the whole zone (top fully
    /// opaque, fading to clear by the bottom edge); each stronger material
    /// after it fades out over a shorter span, so only the topmost band
    /// accumulates all of them for the strongest combined blur.
    private static let materials: [Material] = [
        .ultraThinMaterial, .thinMaterial, .regularMaterial,
    ]

    var body: some View {
        ZStack(alignment: edge == .top ? .top : .bottom) {
            ForEach(Array(Self.materials.enumerated()), id: \.offset) { index, material in
                let fadeEnd = 1 - CGFloat(index) / CGFloat(Self.materials.count)
                Rectangle()
                    .fill(material)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .clear, location: fadeEnd),
                            ],
                            startPoint: edge == .top ? .top : .bottom,
                            endPoint: edge == .top ? .bottom : .top
                        )
                    )
            }
        }
        .frame(height: height)
        // Purely decorative — never intercept clicks meant for the header
        // buttons layered on top of it or rows scrolling underneath.
        .allowsHitTesting(false)
    }
}
