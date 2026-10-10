import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MenuBarView: View {
    @Bindable var store: AppStore
    @State private var newDomain = ""
    @State private var inputError: String?
    @FocusState private var domainFieldFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Lock In").font(.headline)
                Spacer()
                Text("\(usedText(store.totalSecondsUsed)) / \(usedText(store.totalSecondsAllowed))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            FocusView(
                minutes: Binding(get: { store.focusMinutes }, set: { store.focusMinutes = $0; store.save() }),
                until: store.focusUntil,
                minimumMinutes: 1,
                canStart: !store.allRuleIDs.isEmpty
            ) {
                store.startFocus(minutes: store.focusMinutes)
            }

            if let cooldown = store.cooldownUntil, cooldown > store.now {
                Label("Blocked until \(cooldown.formatted(date: .omitted, time: .shortened))", systemImage: "lock.fill")
                    .foregroundStyle(.secondary)
            } else if !store.isFocusing(now: store.now), !store.allRuleIDs.isEmpty, store.browserError == nil {
                Label("Limits active", systemImage: "checkmark.shield")
                    .foregroundStyle(.secondary)
            }

            if let message = store.lastError ?? store.browserError {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Form {
                Section("Websites") {
                    HStack {
                        TextField("website.com/path", text: $newDomain)
                            .textFieldStyle(.roundedBorder)
                            .focused($domainFieldFocused)
                            .onSubmit(addDomain)
                            .onChange(of: newDomain) { _, _ in inputError = nil }
                        Button(action: addDomain) {
                            Image(systemName: "plus")
                        }
                        .help("Add website")
                    }
                    if let inputError {
                        Text(inputError).font(.caption).foregroundStyle(.red)
                    }
                    ForEach(store.rules) { rule in
                        HStack {
                            Text(rule.domain).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Text(usedText(store.records[rule.id]?.secondsUsed ?? 0))
                                .monospacedDigit().foregroundStyle(.secondary)
                            if store.canRemove(rule: rule) {
                                Button {
                                    store.remove(rule: rule)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .help("Remove website")
                            }
                        }
                    }
                }

                Section("Applications") {
                    ForEach(store.applicationRules) { rule in
                        HStack {
                            Text(rule.name).lineLimit(1)
                            Spacer()
                            Text(usedText(store.records[rule.id]?.secondsUsed ?? 0))
                                .monospacedDigit().foregroundStyle(.secondary)
                            if store.canRemove(applicationRule: rule) {
                                Button {
                                    store.remove(applicationRule: rule)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .help("Remove application")
                            }
                        }
                    }
                    Button("Add application", systemImage: "plus", action: addApplication)
                        .disabled(!store.canEditPolicy)
                }

                DisclosureGroup("Limits") {
                    HStack {
                        Text("Session")
                        Spacer()
                        TextField("Minutes", value: sessionLimitMinutes, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 54)
                        Text("min").foregroundStyle(.secondary)
                    }
                    Stepper("Sessions: \(store.sessionCountLimit)", value: sessionCountLimit, in: 1...24)
                    if store.sessionCountLimit > 1 {
                        HStack {
                            Text("Break")
                            Spacer()
                            TextField("Minutes", value: cooldownMinutes, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 54)
                            Text("min").foregroundStyle(.secondary)
                        }
                    }
                    DatePicker("Reset time", selection: resetTime, displayedComponents: .hourAndMinute)
                }
                .disabled(!store.canEditPolicy)
            }
            .formStyle(.grouped)
        }
        .padding(20)
        .frame(width: 380, height: 600)
        .onAppear { store.refreshGuardianStatus() }
    }

    private var sessionLimitMinutes: Binding<Int> {
        Binding(get: { store.sessionLimitMinutes }, set: { store.updateSessionLimitMinutes($0) })
    }

    private var sessionCountLimit: Binding<Int> {
        Binding(get: { store.sessionCountLimit }, set: { store.updateSessionCountLimit($0) })
    }

    private var cooldownMinutes: Binding<Int> {
        Binding(get: { store.cooldownMinutes }, set: { store.updateCooldownMinutes($0) })
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

    private func usedText(_ seconds: Int) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .hourMinuteSecond))
    }

    private func addDomain() {
        if store.addRule(domain: newDomain) {
            newDomain = ""
            inputError = nil
        } else {
            inputError = "Use website.com or website.com/path."
        }
        domainFieldFocused = true
    }

    private func addApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/System/Applications")
        panel.prompt = "Add"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if !store.addApplication(url: url) {
            inputError = "Choose a macOS application other than Lock In."
        }
    }
}
