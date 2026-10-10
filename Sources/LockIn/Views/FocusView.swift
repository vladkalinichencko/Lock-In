import SwiftUI

struct FocusView: View {
    @Binding var minutes: Int
    var until: Date?
    var minimumMinutes: Int
    var canStart: Bool
    var start: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 16) {
                if let until, until > context.date {
                    Label("Focus on", systemImage: "lock.fill")
                        .font(.headline)
                    Text(timerInterval: context.date...until, countsDown: true)
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                    Text("Until \(until.formatted(date: .omitted, time: .shortened))")
                        .foregroundStyle(.secondary)
                } else {
                    HStack {
                        Text("Focus")
                            .font(.headline)
                        Spacer()
                        TextField("Minutes", value: $minutes, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 64)
                            .accessibilityLabel("Focus duration in minutes")
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #else
                            .textFieldStyle(.roundedBorder)
                            #endif
                        Text("min")
                            .foregroundStyle(.secondary)
                    }
                    startButton
                        .disabled(!canStart || !(minimumMinutes...1440).contains(minutes))
                    if !(minimumMinutes...1440).contains(minutes) {
                        Text("\(minimumMinutes)–1440 min")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var startButton: some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            Button(action: start) {
                Label("Start focus", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.extraLarge)
        } else {
            Button(action: start) {
                Label("Start focus", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}
