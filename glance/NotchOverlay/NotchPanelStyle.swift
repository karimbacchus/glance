//
//  NotchPanelStyle.swift
//  glance
//
//  Which silhouette the overlay panel wears on a given screen — passed down
//  through the environment so onboarding's step views can adapt without a parameter.
//

import SwiftUI

enum NotchPanelStyle {
    /// Inverted top corners, flush with the screen's top edge — a MacBook notch.
    case notch
    /// A capsule floating just below the top edge, docked over a hardware Dynamic Island (the hole-punch camera on
    /// the PROLED XDR MacBook Pro). Like `.notch` it never travels — it sits on real hardware and grows out of it, the
    /// way Face ID does on iPhone; like `.pill` its corners are uniform rather than flaring into the screen edge.
    case island
    /// Fully-rounded pill / floating rounded rectangle, detached from the edge — displays with no camera cutout at all.
    case pill

    /// Real camera hardware sits at the top center of the expanded panel (notch or island), so content must keep
    /// clear of it.
    var hasHardwareCutout: Bool { self != .pill }

    /// Whether the panel is permanently docked on the hardware instead of sliding on and off screen.
    var isDocked: Bool { self != .pill }
}

extension EnvironmentValues {
    @Entry var notchPanelStyle: NotchPanelStyle = .notch
}
