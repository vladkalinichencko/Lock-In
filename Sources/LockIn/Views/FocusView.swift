import SwiftUI

struct FocusView: View {
    @Binding var minutes: Int
    var until: Date?
    var pausedAt: Date?
    var minimumMinutes: Int
    var canStart: Bool
    var start: () -> Void
    var togglePause: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let referenceDate = pausedAt ?? context.date
            let isFocusing = until.map { $0 > referenceDate } ?? false
            let isValid = (minimumMinutes...1440).contains(minutes)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(isValid ? "Focus" : "\(minimumMinutes)–1440 min")
                        .foregroundStyle(isValid ? Color.secondary : Color.red)
                        .lineLimit(1)
                    Spacer()
                    TextField("Minutes", value: $minutes, format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 54)
                        .accessibilityLabel("Focus duration in minutes")
                        .disabled(isFocusing)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #else
                        .textFieldStyle(.roundedBorder)
                        #endif
                    Text("min")
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Button(action: start) {
                        Text("Start focus")
                            .opacity(isFocusing ? 0 : 1)
                            .accessibilityHidden(isFocusing)
                            .frame(maxWidth: .infinity)
                            .overlay {
                                if let until, isFocusing {
                                    Text(timerInterval: referenceDate...until, pauseTime: pausedAt, countsDown: true)
                                        .monospacedDigit()
                                        .multilineTextAlignment(.center)
                                        .accessibilityLabel("Focus time remaining")
                                }
                            }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(isFocusing || !canStart || !isValid)
                    Button(action: togglePause) {
                        Image(systemName: pausedAt == nil ? "pause.fill" : "play.fill")
                            .frame(width: 20)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(!isFocusing)
                    .accessibilityLabel(pausedAt == nil ? "Pause focus timer" : "Resume focus timer")
                    #if os(macOS)
                    .help(pausedAt == nil ? "Pause timer" : "Resume timer")
                    #endif
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
