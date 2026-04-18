import SwiftUI

struct DiagnosticScanView: View {
    @ObservedObject var ble: BLEManager
    @ObservedObject var calibration: CalibrationService
    @Environment(\.colorScheme) var colorScheme

    @State private var isScanning = false
    @State private var scanComplete = false
    @State private var countdown: Int = 10
    @State private var capturedFrames: [[UInt16]] = []
    @State private var timer: Timer?
    @State private var leftMetrics: FootMetrics?
    @State private var rightMetrics: FootMetrics?
    @State private var averagedLeft: [UInt16] = []
    @State private var averagedRight: [UInt16] = []

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

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PEDISENSE")
                                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                                .tracking(4)
                                .foregroundColor(textPrimary.opacity(0.9))
                            Text("Diagnostic Scan")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(textPrimary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    if !isScanning && !scanComplete {
                        readyState
                    } else if isScanning {
                        scanningState
                    } else if scanComplete {
                        resultsState
                    }

                    Spacer().frame(height: 20)
                }
            }
        }
    }

    // MARK: - Ready State

    var readyState: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "shoeprints.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.cyan.opacity(0.6))

                Text("Stand evenly on both feet")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(textPrimary)

                Text("Hold still for 10 seconds while the scan captures your pressure distribution")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 40)

            Button(action: startScan) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 16))
                    Text("START SCAN")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.cyan.opacity(0.15))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                )
            }
            .foregroundColor(.cyan)
            .padding(.horizontal, 20)
            .disabled(!ble.isConnected)

            if !ble.isConnected {
                Text("Connect to Pedisense to begin")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.orange)
            }
        }
    }

    // MARK: - Scanning State

    var scanningState: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 30)

            ZStack {
                Circle()
                    .stroke(cardBorder, lineWidth: 4)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: CGFloat(10 - countdown) / 10.0)
                    .stroke(Color.cyan, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: countdown)

                VStack(spacing: 2) {
                    Text("\(countdown)")
                        .font(.system(size: 44, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                    Text("seconds")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(textSecondary)
                }
            }

            Text("Hold still...")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(textPrimary.opacity(0.7))

            Text("\(capturedFrames.count) frames captured")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(textSecondary)
        }
    }

    // MARK: - Results State

    var resultsState: some View {
        VStack(spacing: 16) {
            if let left = leftMetrics, let right = rightMetrics {
                summaryCard(left: left, right: right)
                footCard(title: "LEFT FOOT", metrics: left, readings: averagedLeft)
                footCard(title: "RIGHT FOOT", metrics: right, readings: averagedRight)
                findingsCard(left: left, right: right)
            }

            Button(action: resetScan) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14))
                    Text("SCAN AGAIN")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(cardBg)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(cardBorder, lineWidth: 1)
                )
            }
            .foregroundColor(textPrimary.opacity(0.7))
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Result Cards

    func summaryCard(left: FootMetrics, right: FootMetrics) -> some View {
        let issues = countIssues(left: left, right: right)

        return VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: issues == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(issues == 0 ? .green : .orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(issues == 0 ? "Looking Good" : "\(issues) Issue\(issues > 1 ? "s" : "") Detected")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(textPrimary)
                    Text("Based on \(capturedFrames.count) frames over 10 seconds")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(textSecondary)
                }

                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(issues == 0 ? Color.green.opacity(0.06) : Color.orange.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(issues == 0 ? Color.green.opacity(0.2) : Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }

    func footCard(title: String, metrics: FootMetrics, readings: [UInt16]) -> some View {
        let zones = ["1st Met", "5th Met", "Midfoot", "Med Heel", "Lat Heel"]

        return VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(2)
                .foregroundColor(textSecondary)

            ForEach(0..<5, id: \.self) { i in
                HStack(spacing: 8) {
                    Text(zones[i])
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(textSecondary)
                        .frame(width: 65, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(ColorMap.color(for: Double(readings[i]) / 4095.0))
                                .frame(width: geo.size.width * CGFloat(readings[i]) / 4095.0)
                        }
                    }
                    .frame(height: 12)

                    Text("\(readings[i])")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(textPrimary.opacity(0.7))
                        .frame(width: 40, alignment: .trailing)
                }
            }

            Divider().opacity(0.2)

            HStack(spacing: 0) {
                metricCell(label: "Arch Index", value: String(format: "%.3f", metrics.archIndex),
                          alert: metrics.flatFootFlag, alertText: "FLAT")
                metricCell(label: "Pronation", value: String(format: "%.2f", metrics.pronationIndex),
                          alert: metrics.overpronationFlag, alertText: "OVER")
                metricCell(label: "Heel Center", value: String(format: "%.2f", metrics.heelCentering),
                          alert: abs(metrics.heelCentering - 0.5) > 0.15, alertText: "OFF")
                metricCell(label: "Forefoot", value: String(format: "%.2f", metrics.forefootBalance),
                          alert: false, alertText: "")
            }
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
    }

    func metricCell(label: String, value: String, alert: Bool, alertText: String) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(textSecondary)

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(alert ? .red : textPrimary.opacity(0.85))

            if alert {
                Text(alertText)
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundColor(.red)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.red.opacity(0.15))
                    .cornerRadius(2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    func findingsCard(left: FootMetrics, right: FootMetrics) -> some View {
        var findings: [(icon: String, color: Color, title: String, detail: String)] = []

        if left.flatFootFlag || right.flatFootFlag {
            let sides = [left.flatFootFlag ? "left" : nil, right.flatFootFlag ? "right" : nil]
                .compactMap { $0 }.joined(separator: " and ")
            findings.append((
                icon: "shoeprints.fill",
                color: .red,
                title: "Flat Foot Detected (\(sides))",
                detail: "Arch index above 0.12 indicates collapsed medial arch. The midfoot zone is bearing more weight than normal. Short foot exercises and arch strengthening recommended."
            ))
        }

        if left.overpronationFlag || right.overpronationFlag {
            let sides = [left.overpronationFlag ? "left" : nil, right.overpronationFlag ? "right" : nil]
                .compactMap { $0 }.joined(separator: " and ")
            findings.append((
                icon: "arrow.left.arrow.right",
                color: .orange,
                title: "Overpronation (\(sides))",
                detail: "Pronation index above 1.3 indicates excessive inward rolling. Medial loading is disproportionately high. Lateral strengthening and balance training recommended."
            ))
        }

        if abs(left.heelCentering - 0.5) > 0.15 || abs(right.heelCentering - 0.5) > 0.15 {
            findings.append((
                icon: "circle.bottomhalf.filled",
                color: .yellow,
                title: "Heel Imbalance",
                detail: "Heel centering deviates significantly from 0.50. Weight is not evenly distributed across the heel, which may indicate eversion or inversion."
            ))
        }

        if findings.isEmpty {
            findings.append((
                icon: "checkmark.seal.fill",
                color: .green,
                title: "No Issues Detected",
                detail: "Your pressure distribution looks healthy. All biomechanical metrics are within normal ranges. Continue monitoring for changes over time."
            ))
        }

        return VStack(alignment: .leading, spacing: 10) {
            Text("FINDINGS")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(2)
                .foregroundColor(textSecondary)

            ForEach(findings.indices, id: \.self) { i in
                let finding = findings[i]
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: finding.icon)
                        .font(.system(size: 18))
                        .foregroundColor(finding.color)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(finding.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(textPrimary)
                        Text(finding.detail)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(finding.color.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(finding.color.opacity(0.15), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Logic

    func startScan() {
        isScanning = true
        scanComplete = false
        countdown = 10
        capturedFrames = []

        timer = Timer.scheduledTimer(withTimeInterval: 0.066, repeats: true) { _ in
            let frame = ble.leftReadings + ble.rightReadings
            capturedFrames.append(frame)
        }

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            countdown -= 1
            if countdown <= 0 {
                t.invalidate()
                finishScan()
            }
        }
    }

    func finishScan() {
        timer?.invalidate()
        timer = nil
        isScanning = false

        guard !capturedFrames.isEmpty else {
            resetScan()
            return
        }

        var averaged: [UInt16] = Array(repeating: 0, count: 10)
        for i in 0..<10 {
            let sum = capturedFrames.reduce(0) { $0 + Int($1[i]) }
            averaged[i] = UInt16(sum / capturedFrames.count)
        }

        averagedLeft = Array(averaged[0..<5])
        averagedRight = Array(averaged[5..<10])

        let metricsLeft: [UInt16]
        let metricsRight: [UInt16]

        if calibration.isCalibrated {
            metricsLeft = zip(averagedLeft, calibration.leftBaseline).map { reading, base in
                guard base > 0 else { return reading }
                return UInt16(min(Double(reading) / base * 1000, 65535))
            }
            metricsRight = zip(averagedRight, calibration.rightBaseline).map { reading, base in
                guard base > 0 else { return reading }
                return UInt16(min(Double(reading) / base * 1000, 65535))
            }
        } else {
            metricsLeft = averagedLeft
            metricsRight = averagedRight
        }

        leftMetrics = BiomechanicsAnalyzer.analyze(readings: metricsLeft)
        rightMetrics = BiomechanicsAnalyzer.analyze(readings: metricsRight)

        scanComplete = true

        print("Scan complete: \(capturedFrames.count) frames")
        print("Left avg: \(averagedLeft)")
        print("Right avg: \(averagedRight)")
        if calibration.isCalibrated {
            print("Using calibrated metrics")
        }
        print("Left arch: \(leftMetrics?.archIndex ?? 0), pron: \(leftMetrics?.pronationIndex ?? 0)")
        print("Right arch: \(rightMetrics?.archIndex ?? 0), pron: \(rightMetrics?.pronationIndex ?? 0)")
    }

    func resetScan() {
        isScanning = false
        scanComplete = false
        countdown = 10
        capturedFrames = []
        leftMetrics = nil
        rightMetrics = nil
        averagedLeft = []
        averagedRight = []
    }

    func countIssues(left: FootMetrics, right: FootMetrics) -> Int {
        var count = 0
        if left.flatFootFlag || right.flatFootFlag { count += 1 }
        if left.overpronationFlag || right.overpronationFlag { count += 1 }
        if abs(left.heelCentering - 0.5) > 0.15 || abs(right.heelCentering - 0.5) > 0.15 { count += 1 }
        return count
    }
}
