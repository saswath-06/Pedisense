import SwiftUI
import Combine

struct AlertView: View {
    @ObservedObject var ble: BLEManager
    @ObservedObject var alertEngine: AlertEngine
    @Environment(\.colorScheme) var colorScheme

    var bgColor: Color {
        colorScheme == .dark
            ? Color(red: 0.06, green: 0.06, blue: 0.09)
            : Color(red: 0.96, green: 0.96, blue: 0.98)
    }

    var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }

    var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.45)
    }

    var cardBg: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.04)
            : Color.black.opacity(0.03)
    }

    var cardBorder: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.08)
    }

    let zoneNames = ["1st Met", "5th Met", "Midfoot", "Med Heel", "Lat Heel"]

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PEDISENSE")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .tracking(4)
                            .foregroundColor(textPrimary.opacity(0.9))
                        Text("Pressure Alerts")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(textPrimary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Button(action: {
                    if alertEngine.isMonitoring {
                        alertEngine.stopMonitoring()
                    } else {
                        alertEngine.startMonitoring()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: alertEngine.isMonitoring ? "shield.checkered" : "shield")
                            .font(.system(size: 16))
                        Text(alertEngine.isMonitoring ? "MONITORING" : "START MONITORING")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(alertEngine.isMonitoring ? Color.green.opacity(0.15) : cardBg)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(alertEngine.isMonitoring ? Color.green.opacity(0.4) : cardBorder, lineWidth: 1)
                    )
                }
                .foregroundColor(alertEngine.isMonitoring ? .green : textPrimary.opacity(0.7))
                .padding(.horizontal, 20)

                if alertEngine.isMonitoring {
                    VStack(spacing: 8) {
                        Text("ZONE TIMERS")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(textSecondary)

                        HStack(spacing: 4) {
                            ForEach(0..<5, id: \.self) { i in
                                zoneTimer(index: i, label: "L\(i+1)")
                            }
                        }
                        HStack(spacing: 4) {
                            ForEach(5..<10, id: \.self) { i in
                                zoneTimer(index: i, label: "R\(i-4)")
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                VStack(spacing: 12) {
                    HStack {
                        Text("Threshold")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(textSecondary)
                        Spacer()
                        Text("\(alertEngine.adcThreshold)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(textPrimary.opacity(0.8))
                    }
                    Slider(
                        value: Binding(
                            get: { Double(alertEngine.adcThreshold) },
                            set: { alertEngine.adcThreshold = UInt16($0) }
                        ),
                        in: 1000...3800,
                        step: 100
                    )
                    .tint(.cyan)

                    HStack {
                        Text("Duration")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(textSecondary)
                        Spacer()
                        Text("\(Int(alertEngine.durationLimit))s")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(textPrimary.opacity(0.8))
                    }
                    Slider(
                        value: $alertEngine.durationLimit,
                        in: 5...60,
                        step: 5
                    )
                    .tint(.cyan)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cardBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(cardBorder, lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 8) {
                    Text("ALERT HISTORY")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(textSecondary)
                        .padding(.leading, 4)

                    if alertEngine.activeAlerts.isEmpty {
                        Text("No alerts yet")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    } else {
                        ScrollView {
                            VStack(spacing: 6) {
                                ForEach(alertEngine.activeAlerts) { alert in
                                    alertRow(alert)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }

    func zoneTimer(index: Int, label: String) -> some View {
        let progress = alertEngine.timerProgress(for: index)
        let allReadings = (index < 5 ? ble.leftReadings : ble.rightReadings)
        let sensorIndex = index % 5
        let isAboveThreshold = allReadings[sensorIndex] > alertEngine.adcThreshold

        return VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(textSecondary)

            ZStack {
                Circle()
                    .stroke(cardBorder, lineWidth: 2)
                    .frame(width: 28, height: 28)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        progress > 0.8 ? Color.red : Color.orange,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(-90))

                Circle()
                    .fill(isAboveThreshold ? Color.orange.opacity(0.3) : Color.clear)
                    .frame(width: 22, height: 22)
            }
        }
        .frame(maxWidth: .infinity)
    }

    func alertRow(_ alert: AlertEngine.ZoneAlert) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(.red)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(alert.foot) \(alert.zone)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(textPrimary.opacity(0.85))
                Text("\(Int(alert.duration))s sustained pressure")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(textSecondary)
            }

            Spacer()

            Text(alert.timestamp, style: .time)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(textSecondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red.opacity(0.15), lineWidth: 1)
                )
        )
    }
}
