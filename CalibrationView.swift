import SwiftUI

struct CalibrationView: View {
    @ObservedObject var ble: BLEManager
    @ObservedObject var calibration: CalibrationService
    @Environment(\.colorScheme) var colorScheme

    var bgColor: Color {
        colorScheme == .dark
            ? Color(red: 0.06, green: 0.06, blue: 0.09)
            : Color(red: 0.96, green: 0.96, blue: 0.98)
    }

    var textPrimary: Color { colorScheme == .dark ? .white : .black }
    var textSecondary: Color { colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.45) }
    var cardBg: Color { colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03) }
    var cardBorder: Color { colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08) }

    let zones = ["1st Met", "5th Met", "Midfoot", "Med Heel", "Lat Heel"]

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PEDISENSE")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .tracking(4)
                            .foregroundColor(textPrimary.opacity(0.9))
                        Text("Calibration")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(textPrimary)
                    }
                    Spacer()

                    if calibration.isCalibrated {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                            Text("CALIBRATED")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.green.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                if calibration.isCalibrating {
                    calibratingState
                } else if calibration.isCalibrated {
                    calibratedState
                } else {
                    readyState
                }

                Spacer()
            }
        }
    }

    var readyState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 30)

            Image(systemName: "scale.3d")
                .font(.system(size: 48))
                .foregroundColor(.cyan.opacity(0.6))

            Text("Stand evenly on both feet")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(textPrimary)

            Text("Distribute your weight equally across both feet. This sets your personal baseline so sensor variation is normalized out.")
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: {
                let cal = calibration
                let b = ble
                cal.startCalibration(ble: b)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "tuningfork")
                        .font(.system(size: 16))
                    Text("CALIBRATE")
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
                Text("Connect to Pedisense to calibrate")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.orange)
            }
        }
    }

    var calibratingState: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)

            ZStack {
                Circle()
                    .stroke(cardBorder, lineWidth: 4)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: CGFloat(5 - calibration.countdown) / 5.0)
                    .stroke(Color.cyan, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: calibration.countdown)

                VStack(spacing: 2) {
                    Text("\(calibration.countdown)")
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
        }
    }

    var calibratedState: some View {
        VStack(spacing: 16) {
            baselineCard(title: "LEFT BASELINE", baseline: calibration.leftBaseline)
            baselineCard(title: "RIGHT BASELINE", baseline: calibration.rightBaseline)

            if ble.isConnected {
                let leftValues = ble.leftReadings
                let rightValues = ble.rightReadings
                let leftBase = calibration.leftBaseline
                let rightBase = calibration.rightBaseline

                let leftNorm: [Double] = zip(leftValues, leftBase).map { reading, base in
                    guard base > 0 else { return 0 }
                    return (Double(reading) / base) * 100.0
                }
                let rightNorm: [Double] = zip(rightValues, rightBase).map { reading, base in
                    guard base > 0 else { return 0 }
                    return (Double(reading) / base) * 100.0
                }

                normalizedCard(
                    title: "LIVE (% OF BASELINE)",
                    leftNorm: leftNorm,
                    rightNorm: rightNorm
                )
            }

            Button(action: {
                let cal = calibration
                cal.reset()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14))
                    Text("RECALIBRATE")
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

    func baselineCard(title: String, baseline: [Double]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
                                .fill(Color.cyan.opacity(0.5))
                                .frame(width: geo.size.width * CGFloat(baseline[i] / 4095.0))
                        }
                    }
                    .frame(height: 12)

                    Text(String(format: "%.0f", baseline[i]))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(textPrimary.opacity(0.7))
                        .frame(width: 40, alignment: .trailing)
                }
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

    func normalizedCard(title: String, leftNorm: [Double], rightNorm: [Double]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(2)
                .foregroundColor(textSecondary)

            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("LEFT")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundColor(textSecondary)
                    ForEach(0..<5, id: \.self) { i in
                        HStack {
                            Text(zones[i])
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(textSecondary)
                                .frame(width: 55, alignment: .leading)
                            Text(String(format: "%.0f%%", leftNorm[i]))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(normColor(leftNorm[i]))
                                .frame(width: 50, alignment: .trailing)
                        }
                    }
                }

                VStack(spacing: 4) {
                    Text("RIGHT")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundColor(textSecondary)
                    ForEach(0..<5, id: \.self) { i in
                        HStack {
                            Text(zones[i])
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(textSecondary)
                                .frame(width: 55, alignment: .leading)
                            Text(String(format: "%.0f%%", rightNorm[i]))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(normColor(rightNorm[i]))
                                .frame(width: 50, alignment: .trailing)
                        }
                    }
                }
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

    func normColor(_ value: Double) -> Color {
        if value < 50 { return .blue }
        if value < 80 { return .cyan }
        if value < 120 { return .green }
        if value < 150 { return .yellow }
        return .red
    }
}
