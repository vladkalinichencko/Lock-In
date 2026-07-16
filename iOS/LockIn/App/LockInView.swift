import FamilyControls
import SwiftUI

struct LockInView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var store: LockInStore

    var body: some View {
        NavigationStack {
            List {
                if !store.isAuthorized {
                    Section {
                        Button("Allow Screen Time Access") {
                            Task {
                                await store.requestAuthorization()
                            }
                        }
                    }
                }

                if let errorMessage = store.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    HStack {
                        Text("Session")
                        Spacer()
                        TextField("", value: sessionLimitMinutes, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 72)
                            .disabled(!store.snapshot.canEditPolicy)
                        Text("min")
                            .foregroundStyle(.secondary)
                    }

                    Stepper(value: sessionCountLimit, in: 1...24) {
                        HStack {
                            Text("Sessions")
                            Spacer()
                            Text("\(store.snapshot.sessionCountLimit)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(!store.snapshot.canEditPolicy)

                    if store.snapshot.sessionCountLimit > 1 {
                        HStack {
                            Text("Break")
                            Spacer()
                            TextField("", value: breakMinutes, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 72)
                                .disabled(!store.snapshot.canEditPolicy)
                            Text("min")
                                .foregroundStyle(.secondary)
                        }
                    }

                    DatePicker("Reset time", selection: resetTime, displayedComponents: .hourAndMinute)
                        .disabled(!store.snapshot.canEditPolicy)
                }

                if store.isAuthorized {
                    Section {
                        selectedRows

                        Button("Edit Selection") {
                            store.isPickerPresented = true
                        }
                        .disabled(!store.snapshot.canEditPolicy)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .scrollEdgeEffectStyle(.soft, for: .top)
            .safeAreaBar(edge: .top, alignment: .leading, spacing: 0) {
                usedHeader
            }
            .familyActivityPicker(isPresented: $store.isPickerPresented, selection: selection)
            .task {
                store.refreshAuthorizationStatus()
                await store.refreshNotificationStatus()
                await store.requestNotificationAuthorizationOnLaunch()
            }
            .onChange(of: scenePhase) { _, newValue in
                if newValue == .active {
                    store.refreshAuthorizationStatus()
                    Task {
                        await store.refreshNotificationStatus()
                    }
                }
            }
        }
    }

    private var usedHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Used")
                .font(.system(.headline, design: .default).weight(.semibold))
            Text("\(durationText(store.snapshot.cumulativeSecondsUsed)) / \(durationText(store.snapshot.totalSecondsAllowed))")
                .font(.system(.title2, design: .default).weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var selectedRows: some View {
        if store.snapshot.selection.applicationTokens.isEmpty &&
            store.snapshot.selection.categoryTokens.isEmpty &&
            store.snapshot.selection.webDomainTokens.isEmpty {
            Text("No selection")
                .foregroundStyle(.secondary)
        } else {
            ForEach(Array(store.snapshot.selection.applicationTokens), id: \.self) { token in
                Label(token)
            }
            ForEach(Array(store.snapshot.selection.categoryTokens), id: \.self) { token in
                Label(token)
            }
            ForEach(Array(store.snapshot.selection.webDomainTokens), id: \.self) { token in
                Label(token)
            }
        }
    }

    private var selection: Binding<FamilyActivitySelection> {
        Binding(
            get: { store.snapshot.selection },
            set: { store.saveSelection($0) }
        )
    }

    private var sessionLimitMinutes: Binding<Int> {
        Binding(
            get: { store.snapshot.sessionLimitMinutes },
            set: { store.updateSessionLimitMinutes($0) }
        )
    }

    private var sessionCountLimit: Binding<Int> {
        Binding(
            get: { store.snapshot.sessionCountLimit },
            set: { store.updateSessionCountLimit($0) }
        )
    }

    private var breakMinutes: Binding<Int> {
        Binding(
            get: { store.snapshot.breakMinutes },
            set: { store.updateBreakMinutes($0) }
        )
    }

    private var resetTime: Binding<Date> {
        Binding(
            get: {
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = store.snapshot.resetHour
                components.minute = store.snapshot.resetMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { store.updateResetTime($0) }
        )
    }

    private func durationText(_ seconds: Int) -> String {
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
}

#Preview {
    LockInView(store: LockInStore())
}
