import SwiftUI

/// A slider's end icon that moves the value one step toward its end when pressed, and keeps
/// stepping for as long as it's held.
struct NudgeButton: View {
    let end: SliderEnd
    let action: () -> Void
    @State private var repeater: Task<Void, Never>?
    @Environment(\.isEnabled) private var isEnabled

    /// The wait before holding starts to repeat, and the time between repeats after that.
    private static let holdDelay = Duration.milliseconds(400)
    private static let repeatInterval = Duration.milliseconds(60)

    var body: some View {
        end.image
            .opacity(repeater == nil ? 1 : 0.5)
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in start() }
                .onEnded { _ in stop() })
            .onDisappear(perform: stop)
    }

    private func start() {
        guard isEnabled, repeater == nil else { return }
        action()
        repeater = Task {
            try? await Task.sleep(for: Self.holdDelay)
            while !Task.isCancelled {
                action()
                try? await Task.sleep(for: Self.repeatInterval)
            }
        }
    }

    private func stop() {
        repeater?.cancel()
        repeater = nil
    }
}
