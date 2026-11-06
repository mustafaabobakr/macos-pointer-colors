import SwiftUI

/// Each 1% of the charge as a row, newest first: how much of it the mouse was in use and how much
/// it sat idle, with the whole time at the end. Rows from before use was recorded are estimated
/// and drawn faded. Pointing at a row tells when it started.
struct DrainSteps: View {
    let charge: Charge
    /// Off while the drain report shows, which has the measured in-use pace.
    var showsPace = true
    @State private var selection: String?
    @Environment(\.appTextScale) private var scale

    var body: some View {
        let steps = Array(charge.steps.reversed())
        let longest = steps.map { max($0.inUse, $0.idle) }.max() ?? 1
        VStack(alignment: .leading, spacing: 12 * scale) {
            header(selected: steps.first { Self.title(of: $0) == selection })
            ScrollView {
                LazyVStack(spacing: 4 * scale) {
                    ForEach(steps, id: \.start) { row($0, longest: longest) }
                }
            }
            .frame(maxHeight: 340 * scale)
            .fixedSize(horizontal: false, vertical: steps.count < 8)
            footer(estimated: steps.contains { $0.inUseSeconds == nil })
        }
    }

    /// One 1%: its levels, a bar for its time in use and one for its time idle, each with its
    /// hours beside it, and the whole time at the end.
    private func row(_ step: DrainStep, longest: TimeInterval) -> some View {
        let title = Self.title(of: step)
        return HStack(spacing: 10 * scale) {
            Text(title).frame(width: 96 * scale, alignment: .leading)
            VStack(spacing: 3 * scale) {
                line(step.inUse, of: longest, color: UsageColors.inUse)
                line(step.idle, of: longest, color: UsageColors.idle)
            }
            Text(ChargeText.duration(step.duration)).frame(width: 58 * scale, alignment: .trailing)
        }
        .appFont(.caption)
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .opacity(step.inUseSeconds == nil ? 0.6 : 1)
        .padding(.vertical, 5 * scale)
        .padding(.horizontal, 6 * scale)
        .background(selection == title ? Color.primary.opacity(0.06) : .clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onHover { selection = $0 ? title : (selection == title ? nil : selection) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.detail(of: step))
    }

    /// A bar as long as `time` is of `longest`, with the time written just after it. Under a
    /// minute draws nothing, keeping the row's height.
    private func line(_ time: TimeInterval, of longest: TimeInterval, color: Color) -> some View {
        GeometryReader { proxy in
            let room = max(0, proxy.size.width - 60 * scale)
            HStack(spacing: 6 * scale) {
                if time >= 60 {
                    RoundedRectangle(cornerRadius: 3 * scale).fill(color)
                        .frame(width: max(3, room * time / max(longest, 1)), height: 9 * scale)
                    Text(ChargeText.duration(time)).font(.system(size: 10 * scale)).monospacedDigit().fixedSize()
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 13 * scale)
    }

    private func header(selected: DrainStep?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Each 1%, in use and idle").appFont(.caption, weight: .semibold)
            Spacer()
            if let selected { Text(Self.detail(of: selected)).appFont(.caption).monospacedDigit() } else { UsageLegend() }
        }
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func footer(estimated: Bool) -> some View {
        let pace = charge.inUsePerPercent.flatMap { showsPace ? $0 : nil }.map {
            String(localized: "In use, 1% every \(ChargeText.duration($0)): about \(ChargeText.days($0 * 100 / 86_400)) of use on a full charge.")
        }
        let note = estimated ? String(localized: "Faded rows are from before use was recorded, so their split is a guess.") : nil
        let text = [pace, note].compactMap { $0 }.joined(separator: " ")
        if !text.isEmpty { Text(text).appFont(.caption).foregroundStyle(.secondary) }
    }

    static func title(of step: DrainStep) -> String {
        step.isOngoing ? String(localized: "\(step.level)% so far") : "\(step.from)% → \(step.level)%"
    }

    /// "95% → 94% · 1h 42m in use · 3m idle · from Nov 2 at 1:47 PM"
    static func detail(of step: DrainStep) -> String {
        let guess = step.inUseSeconds == nil ? String(localized: " (estimated)") : ""
        return String(localized: "\(title(of: step)) · \(ChargeText.duration(step.inUse)) in use · \(ChargeText.duration(step.idle)) idle\(guess) · from \(ChargeText.date(step.start))")
    }
}
