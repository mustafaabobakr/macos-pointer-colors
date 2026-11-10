import SwiftUI

/// Where a mouse's battery goes: its drain in use and idle, how long a charge lasts the way it's
/// used, and tips. Until enough drops are measured, how many more it needs.
struct DrainReportView: View {
    let mouse: MouseHistory
    let idleTip: IdleTipThreshold
    let battery: BatterySettings
    @Environment(\.appTextScale) private var scale

    var body: some View {
        VStack(alignment: .leading, spacing: 12 * scale) {
            Text("Drain report").appFont(.caption, weight: .semibold).foregroundStyle(.secondary)
            if let report = mouse.drainReport(useDays: useDays) { content(report) } else { waiting }
        }
    }

    private func content(_ report: DrainReport) -> some View {
        VStack(alignment: .leading, spacing: 12 * scale) {
            HStack(spacing: 10 * scale) {
                StatTile(value: ChargeText.duration(3_600 / report.inUsePerHour), label: String(localized: "In use, for each 1%"))
                StatTile(value: ChargeText.rate(report.idlePerDay), label: String(localized: "Idle, when it isn't used"))
                StatTile(value: report.fullChargeDays.map { ChargeText.days($0) } ?? "—",
                         label: String(localized: "A full charge, at your \(ChargeText.duration(report.useHoursPerDay * 3_600)) of use a day"))
            }
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10 * scale) {
                StatTile(value: ChargeText.duration(report.totalInUse), label: String(localized: "Used in total"))
                StatTile(value: ChargeText.duration(report.totalIdle), label: String(localized: "Idle in total"))
            }
            .fixedSize(horizontal: false, vertical: true)
            let tips = report.tips(idleShare: idleTip.share, trend: mouse.trend, wearShare: battery.wearShare)
            ForEach(Array(tips.enumerated()), id: \.offset) { tip($0.element, report: report) }
            if tips.isEmpty { tipRow(String(localized: "Most of the drain is from use, so there's nothing to change."), symbol: "checkmark.circle") }
            Text("Worked out each midnight from \(report.steps) measured drops of 1%, with your use over the last \(useDays) days. It settles as more come in.")
                .appFont(.caption)
                .foregroundStyle(.secondary)
            history
        }
    }

    @ViewBuilder
    private var history: some View {
        let estimates = mouse.drainEstimates(days: Int(battery.chartDays), useDays: useDays)
        if estimates.count > 1 {
            EstimateHistory(estimates: estimates).padding(.top, 6 * scale)
        } else {
            Text("A chart of how the estimate moves shows here after its second midnight.")
                .appFont(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var useDays: Int { Int(battery.useDays) }

    private var waiting: some View {
        let midnight = Calendar.current.startOfDay(for: .now)
        let measured = DrainReport.measured(mouse.allSteps.filter { $0.end <= midnight }).count
        return Text("Shows once \(DrainReport.minimumSteps) drops of 1% are measured by a midnight: \(measured) so far.")
            .appFont(.caption)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func tip(_ tip: DrainTip, report: DrainReport) -> some View {
        switch tip {
        case .idle(let share):
            let saved = ChargeText.rate(report.idlePerHour * (24 - report.useHoursPerDay))
            tipRow(String(localized: "Idle is \(Int((share * 100).rounded()))% of each day's drain. Switching the mouse off when you aren't using it, like overnight, saves about \(saved)."),
                   symbol: "power")
        case .wear(let trend):
            tipRow(String(localized: "Charges now last \(Int((-trend * 100).rounded()))% less than your first ones, so the battery may be wearing."),
                   symbol: "exclamationmark.triangle")
        }
    }

    private func tipRow(_ text: String, symbol: String) -> some View {
        Label { Text(text) } icon: { Image(systemName: symbol).foregroundStyle(Color.accentColor) }
            .appFont(.caption)
            .padding(10 * scale)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8 * scale, style: .continuous))
    }
}
