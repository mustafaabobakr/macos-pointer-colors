import SwiftUI

/// Where each documented feature, and each control a feature clip points at, sits on screen,
/// recorded only while the app records a feature clip (see docs/features/README.md). In normal
/// use `featureSpot` adds nothing.
@MainActor
enum FeatureSpots {
    static let isRecording = ScreenshotRenderer.isRendering
    /// Frames in the rendered window's coordinates, top-left origin, in points. A spot on a Form
    /// section lands on each of its rows, so the frames are joined into one.
    private(set) static var frames: [String: CGRect] = [:]

    static func record(_ id: String, _ frame: CGRect) { frames[id] = frames[id]?.union(frame) ?? frame }
    static func reset() { frames = [:] }
}

extension View {
    /// Marks this view as feature `id` from docs/features/features.json, or as a control a clip
    /// points at (`clip-…`, see FeatureClipScripts).
    func featureSpot(_ id: String) -> some View {
        background {
            if FeatureSpots.isRecording {
                GeometryReader { proxy in
                    let frame = proxy.frame(in: .global)
                    Color.clear
                        .onAppear { FeatureSpots.record(id, frame) }
                        .onChange(of: frame) { FeatureSpots.record(id, frame) }
                }
            }
        }
    }
}

/// Where a feature clip's pointer is, in the rendered window's points from the top left. Set only
/// while FeatureClipRecorder records, since hover can't be simulated in an offscreen window.
@MainActor
@Observable
final class ClipPointer {
    static let shared = ClipPointer()
    var location: CGPoint?
}

extension View {
    /// While a feature clip records, calls `perform` as its pointer moves over this view, the way
    /// `onContinuousHover` would. In normal use it adds nothing.
    func clipHover(perform: @escaping (HoverPhase) -> Void) -> some View {
        background {
            if FeatureSpots.isRecording {
                GeometryReader { proxy in
                    let frame = proxy.frame(in: .global)
                    Color.clear.onChange(of: ClipPointer.shared.location) { _, location in
                        guard let location, frame.contains(location) else { return }
                        perform(.active(CGPoint(x: location.x - frame.minX, y: location.y - frame.minY)))
                    }
                }
            }
        }
    }
}
