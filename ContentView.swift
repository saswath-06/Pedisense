import SwiftUI

struct ContentView: View {
    @StateObject private var ble: BLEManager
    @StateObject private var alertEngine: AlertEngine
    @StateObject private var calibration = CalibrationService()

    init() {
        let bleManager = BLEManager()
        let engine = AlertEngine(bleManager: bleManager)
        bleManager.alertEngine = engine
        _ble = StateObject(wrappedValue: bleManager)
        _alertEngine = StateObject(wrappedValue: engine)
    }

    var body: some View {
        if !calibration.isCalibrated {
            CalibrationView(ble: ble, calibration: calibration)
                .onAppear() {
                    calibration.loadSavedCalibration()
                }
        } else {
            TabView {
                HeatmapView(ble: ble, calibration: calibration)
                    .tabItem {
                        Image(systemName: "figure.walk")
                        Text("Live")
                    }

                DiagnosticScanView(ble: ble, calibration: calibration)
                    .tabItem {
                        Image(systemName: "waveform.path.ecg")
                        Text("Scan")
                    }

                ExerciseView(ble: ble, calibration: calibration)
                    .tabItem {
                        Image(systemName: "figure.strengthtraining.functional")
                        Text("Exercise")
                    }

                AlertView(ble: ble, alertEngine: alertEngine)
                    .tabItem {
                        Image(systemName: "exclamationmark.triangle")
                        Text("Alerts")
                    }

                TrendsView()
                    .tabItem {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                        Text("Trends")
                    }

                ReportView(ble: ble, calibration: calibration)
                    .tabItem {
                        Image(systemName: "doc.text")
                        Text("Report")
                    }

                CalibrationView(ble: ble, calibration: calibration)
                    .tabItem {
                        Image(systemName: "tuningfork")
                        Text("Calibrate")
                    }
                DebugView(ble: ble)
                    .tabItem {
                        Image(systemName: "ant")
                        Text("Debug")
                    }
            }
            .tint(.cyan)
        }
    }
}

struct DebugView: View {
    @ObservedObject var ble: BLEManager
    @Environment(\.colorScheme) var colorScheme

    let zones = ["1st Met", "5th Met", "Midfoot", "Med Heel", "Lat Heel"]

    var bgColor: Color {
        colorScheme == .dark
            ? Color(red: 0.06, green: 0.06, blue: 0.09)
            : Color(red: 0.96, green: 0.96, blue: 0.98)
    }

    var textColor: Color { colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8) }
    var labelColor: Color { colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.5) }
    var headerColor: Color { colorScheme == .dark ? .white.opacity(0.35) : .black.opacity(0.35) }
    var barBg: Color { colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06) }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 20) {
                HStack {
                    Circle()
                        .fill(ble.isConnected ? .green : .orange)
                        .frame(width: 10, height: 10)
                    Text(ble.isConnected ? "Connected" : "Scanning...")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(textColor)
                }
                .padding(.top)

                sensorBlock(title: "LEFT FOOT", readings: ble.leftReadings)
                sensorBlock(title: "RIGHT FOOT", readings: ble.rightReadings)

                HStack(spacing: 12) {
                    debugButton("L Motor", color: .cyan) { ble.buzzLeft() }
                    debugButton("R Motor", color: .cyan) { ble.buzzRight() }
                    debugButton("Both", color: .red) { ble.buzzBoth() }
                }
                .padding(.horizontal)

                Spacer()
            }
        }
    }

    func sensorBlock(title: String, readings: [UInt16]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(2)
                .foregroundColor(headerColor)
                .padding(.leading, 4)

            ForEach(0..<5, id: \.self) { i in
                HStack(spacing: 8) {
                    Text(zones[i])
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(labelColor)
                        .frame(width: 70, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(barBg)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(ColorMap.color(for: Double(readings[i]) / 4095.0))
                                .frame(width: geo.size.width * CGFloat(readings[i]) / 4095.0)
                        }
                    }
                    .frame(height: 14)

                    Text("\(readings[i])")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(textColor)
                        .frame(width: 45, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    func debugButton(_ label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(color.opacity(0.12))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        }
        .foregroundColor(color)
    }
}
