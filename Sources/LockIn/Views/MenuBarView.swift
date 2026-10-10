import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MenuBarView: View {
    @Bindable var store: AppStore
    @State private var newDomain = ""
    @State private var inputError: String?
    @FocusState private var domainFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Lock In")
                    .font(.headline)
                Spacer()
                Text("\(usedText(store.totalSecondsUsed)) / \(usedText(store.totalSecondsAllowed))")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            FocusView(
                minutes: Binding(get: { store.focusMinutes }, set: { store.focusMinutes = $0; store.save() }),
                until: store.focusUntil,
                pausedAt: store.focusPausedAt,
                minimumMinutes: 1,
                canStart: !store.allRuleIDs.isEmpty
            ) {
                store.startFocus(minutes: store.focusMinutes)
            } togglePause: {
                store.toggleFocusPause()
            }

            Divider()

            HStack(spacing: 6) {
                TextField("website.com", text: $newDomain)
                    .textFieldStyle(.roundedBorder)
                    .focused($domainFieldFocused)
                    .onSubmit(addDomain)
                    .onChange(of: newDomain) { _, _ in
                        inputError = nil
                    }
                Button(action: addDomain) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .help("Add website")
            }

            HStack {
                Text("Applications")
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: addApplication) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .disabled(!store.canEditPolicy)
                .help("Add application")
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                ForEach(store.rules) { rule in
                    HStack(spacing: 8) {
                        Text(rule.domain)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                        Text(usedText(secondsUsed(for: rule)))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 64, alignment: .trailing)
                        Button {
                            store.remove(rule: rule)
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.plain)
                        .disabled(!store.canRemove(rule: rule))
                        .help("Remove")
                    }
                }

                ForEach(store.applicationRules) { rule in
                    HStack(spacing: 8) {
                        Text(rule.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                        Text(usedText(store.records[rule.id]?.secondsUsed ?? 0))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 64, alignment: .trailing)
                        Button {
                            store.remove(applicationRule: rule)
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.plain)
                        .disabled(!store.canRemove(applicationRule: rule))
                        .help("Remove")
                    }
                }
            }

            Divider()

            HStack {
                Text("Session")
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("", value: sessionLimitMinutes, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 54)
                    .multilineTextAlignment(.trailing)
                    .onSubmit { store.save() }
                    .disabled(!store.canEditPolicy)
                Text("min")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Sessions")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(store.sessionCountLimit)")
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 28, alignment: .trailing)
                Stepper("", value: sessionCountLimit, in: 1...24)
                    .labelsHidden()
                    .disabled(!store.canEditPolicy)
            }

            HStack {
                Text("Break")
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("", value: cooldownMinutes, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 54)
                    .multilineTextAlignment(.trailing)
                    .onSubmit { store.save() }
                    .disabled(!store.canEditPolicy || store.sessionCountLimit == 1)
                Text("min")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Reset time")
                    .foregroundStyle(.secondary)
                Spacer()
                DatePicker("", selection: resetTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .fixedSize()
                    .disabled(!store.canEditPolicy)
            }

            Text(" ")
                .font(.caption)
                .lineLimit(2, reservesSpace: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .hidden()
                .overlay(alignment: .topLeading) {
                    Text(inputError ?? store.lastError ?? store.browserError ?? cooldownText ?? "")
                        .font(.caption)
                        .foregroundStyle(inputError != nil || store.lastError != nil || store.browserError != nil ? Color.red : Color.secondary)
                        .lineLimit(2)
                }
        }
        .padding(12)
        .fixedSize()
        .onAppear {
            store.refreshGuardianStatus()
        }
    }

    private var sessionLimitMinutes: Binding<Int> {
        Binding(
            get: { store.sessionLimitMinutes },
            set: { store.updateSessionLimitMinutes($0) }
        )
    }

    private var sessionCountLimit: Binding<Int> {
        Binding(
            get: { store.sessionCountLimit },
            set: { store.updateSessionCountLimit($0) }
        )
    }

    private var cooldownMinutes: Binding<Int> {
        Binding(
            get: { store.cooldownMinutes },
            set: { store.updateCooldownMinutes($0) }
        )
    }

    private var resetTime: Binding<Date> {
        Binding(
            get: {
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = store.resetHour
                components.minute = store.resetMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                store.updateResetHour(components.hour ?? store.resetHour)
                store.updateResetMinute(components.minute ?? store.resetMinute)
            }
        )
    }

    private func secondsUsed(for rule: BlockRule) -> Int {
        store.records[rule.id]?.secondsUsed ?? 0
    }

    private func usedText(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m \(remainingSeconds)s"
        }
        if minutes > 0 {
            return "\(minutes)m \(remainingSeconds)s"
        }
        return "\(remainingSeconds)s"
    }

    private var cooldownText: String? {
        guard let cooldownUntil = store.cooldownUntil else {
            return nil
        }
        let seconds = max(0, Int(cooldownUntil.timeIntervalSince(store.now).rounded(.up)))
        return "Break \(usedText(seconds))"
    }

    private func addDomain() {
        if store.addRule(domain: newDomain) {
            newDomain = ""
            inputError = nil
        } else {
            inputError = "Use domain.com or domain.com/path. Queries are not supported."
        }
        domainFieldFocused = true
    }

    private func addApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/System/Applications")
        panel.prompt = "Add"
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        if !store.addApplication(url: url) {
            inputError = "Choose a macOS application other than Lock In."
        }
    }
}
