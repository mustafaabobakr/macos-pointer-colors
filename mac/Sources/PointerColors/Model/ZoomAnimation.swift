import Foundation

/// How far Smart zoom has grown, from 0 (not zoomed) to 1 (fully zoomed), moving toward `target`
/// at a steady pace that takes `length` seconds end to end.
struct ZoomAnimation {
    var length: TimeInterval
    /// 1 while zooming in or zoomed, 0 while zooming out.
    var target = 0.0
    private(set) var progress = 0.0

    var isFinished: Bool { progress == target }

    /// Eased so it starts quickly and settles gently.
    var eased: Double { 1 - pow(1 - progress, 3) }

    mutating func advance(by seconds: TimeInterval) {
        guard length > 0 else { progress = target; return }
        let step = seconds / length
        progress = target > progress ? min(target, progress + step) : max(target, progress - step)
    }
}
