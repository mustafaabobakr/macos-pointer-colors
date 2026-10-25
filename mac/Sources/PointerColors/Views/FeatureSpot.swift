import SwiftUI

/// Where each documented feature sits on screen, recorded only while the app renders feature
/// screenshots (see docs/features/README.md). In normal use `featureSpot` adds nothing.
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
    /// Marks this view as feature `id` from docs/features/features.json.
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
