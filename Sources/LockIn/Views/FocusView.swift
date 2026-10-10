import SwiftUI

struct FocusView: View {
    @Binding var minutes: Int
    var until: Date?
    var minimumMinutes: Int
    var canStart: Bool
    var start: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let isFocusing = until.map { $0 > context.date } ?? false
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
                Button(action: start) {
                    Text("Start focus")
                        .opacity(isFocusing ? 0 : 1)
                        .accessibilityHidden(isFocusing)
                        .frame(maxWidth: .infinity)
                        .overlay {
                            if let until, isFocusing {
                                Text(timerInterval: context.date...until, countsDown: true)
                                    .monospacedDigit()
                                    .multilineTextAlignment(.center)
                                    .accessibilityLabel("Focus time remaining")
                            }
                        }
                }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(isFocusing || !canStart || !isValid)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
