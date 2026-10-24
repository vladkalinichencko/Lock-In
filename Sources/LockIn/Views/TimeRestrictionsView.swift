import SwiftUI

struct TimeRestrictionsView: View {
    @Binding var restrictions: TimeRestrictions
    var sessionMinutes: Int

    var body: some View {
        Stepper(value: Binding(
            get: { restrictions.warningMinutes(for: sessionMinutes) },
            set: { restrictions.warningMinutes = $0 }
        ), in: 0...max(0, sessionMinutes - 1)) {
            HStack {
                Text("Warn before")
                Spacer()
                Text("\(restrictions.warningMinutes(for: sessionMinutes)) min")
                    .monospacedDigit()
            }
        }
        Toggle("Downtime", isOn: Binding(
            get: { restrictions.downtime != nil },
            set: { restrictions.downtime = $0 ? ClockInterval() : nil }
        ))
        DatePicker("From", selection: clock(\.start), displayedComponents: .hourAndMinute)
            .disabled(restrictions.downtime == nil)
        DatePicker("Until", selection: clock(\.end), displayedComponents: .hourAndMinute)
            .disabled(restrictions.downtime == nil)
    }

    private func clock(_ keyPath: WritableKeyPath<ClockInterval, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minute = (restrictions.downtime ?? ClockInterval())[keyPath: keyPath]
                return Calendar.current.date(
                    bySettingHour: minute / 60, minute: minute % 60, second: 0, of: .now
                ) ?? .now
            },
            set: { date in
                restrictions.downtime?[keyPath: keyPath] = Calendar.current.component(.hour, from: date) * 60
                    + Calendar.current.component(.minute, from: date)
            }
        )
    }
}
