import SwiftUI

struct FocusView: View {
    @Binding var minutes: Int
    var until: Date?
    var minimumMinutes: Int
    var canStart: Bool
    var start: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 8) {
                if let until, until > context.date {
                    HStack {
                        Text("Focus")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(timerInterval: context.date...until, countsDown: true)
                            .font(.system(.body, design: .monospaced))
                    }
                } else {
                    HStack {
                        Text("Focus")
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField("Minutes", value: $minutes, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 54)
                            .accessibilityLabel("Focus duration in minutes")
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #else
                            .textFieldStyle(.roundedBorder)
                            #endif
                        Text("min")
                            .foregroundStyle(.secondary)
                    }
                    Button(action: start) {
                        Text("Start focus")
                            .frame(maxWidth: .infinity)
                    }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
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
}
