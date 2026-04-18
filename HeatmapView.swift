import SwiftUI

struct HeatmapView: View {
    @ObservedObject var ble: BLEManager
    @ObservedObject var calibration: CalibrationService
    @Environment(\.colorScheme) var colorScheme
    @State private var pulseConnection = false

    let gridResolution: Int = 50

    var bgPrimary: Color {
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

    var textTertiary: Color {
        colorScheme == .dark ? .white.opacity(0.25) : .black.opacity(0.3)
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

    var buttonBg: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.04)
    }

    var buttonBorder: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.1)
            : Color.black.opacity(0.1)
    }

    var buttonText: Color {
        colorScheme == .dark
            ? .white.opacity(0.7)
            : .black.opacity(0.6)
    }

    var footOutline: Color {
        colorScheme == .dark
            ? .white.opacity(0.25)
            : .black.opacity(0.2)
    }

    var footGlow: Color {
        colorScheme == .dark
            ? .cyan.opacity(0.08)
            : .cyan.opacity(0.05)
    }

    var sensorDot: Color {
        colorScheme == .dark
            ? .white.opacity(0.9)
            : .white.opacity(0.95)
    }

    // Normalize readings using calibration baseline
    // Returns 0.0 to ~2.0 range (0% to 200% of baseline)
    func normalizedValues(_ readings: [UInt16], baseline: [Double]) -> [CGFloat] {
        return zip(readings, baseline).map { reading, base in
            guard base > 0 else { return CGFloat(reading) / 4095.0 }
            // Clamp to 0-1 range where 0 = no pressure, 1 = 2x baseline
            return min(CGFloat(Double(reading) / (base * 2.0)), 1.0)
        }
    }

    var body: some View {
        ZStack {
            bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                    .padding(.top, 8)

                Spacer().frame(height: 20)

                HStack(spacing: 24) {
                    FootHeatmap(
                        values: normalizedValues(ble.leftReadings, baseline: calibration.leftBaseline),
                        positions: HeatmapRenderer.leftSensorPositions,
                        isLeft: true,
                        resolution: gridResolution,
                        label: "LEFT",
                        outlineColor: footOutline,
                        glowColor: footGlow,
                        dotColor: sensorDot,
                        labelColor: textSecondary
                    )

                    FootHeatmap(
                        values: normalizedValues(ble.rightReadings, baseline: calibration.rightBaseline),
                        positions: HeatmapRenderer.rightSensorPositions,
                        isLeft: false,
                        resolution: gridResolution,
                        label: "RIGHT",
                        outlineColor: footOutline,
                        glowColor: footGlow,
                        dotColor: sensorDot,
                        labelColor: textSecondary
                    )
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 20)

                metricsPanel
                    .padding(.horizontal, 20)

                Spacer().frame(height: 16)

                legendBar
                    .padding(.horizontal, 40)

                Spacer().frame(height: 12)

                motorControls
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Header

    var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("PEDISENSE")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .tracking(4)
                    .foregroundColor(textPrimary.opacity(0.9))
                Text("Live Pressure Map")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(textPrimary)
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(ble.isConnected ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                    .shadow(color: ble.isConnected ? .green.opacity(0.6) : .orange.opacity(0.6), radius: 4)
                    .scaleEffect(pulseConnection ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulseConnection)
                    .onAppear { pulseConnection = true }
                Text(ble.isConnected ? "LIVE" : "SCANNING")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(ble.isConnected ? .green : .orange)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(cardBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(ble.isConnected ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Metrics

    var metricsPanel: some View {
        HStack(spacing: 0) {
            MetricTile(title: "ARCH", subtitle: "Left", value: archIndex(ble.leftReadings),
                       format: "%.3f", alert: archIndex(ble.leftReadings) > 0.12, alertLabel: "FLAT",
                       textPrimary: textPrimary, textSecondary: textTertiary)
            metricDivider
            MetricTile(title: "ARCH", subtitle: "Right", value: archIndex(ble.rightReadings),
                       format: "%.3f", alert: archIndex(ble.rightReadings) > 0.12, alertLabel: "FLAT",
                       textPrimary: textPrimary, textSecondary: textTertiary)
            metricDivider
            MetricTile(title: "PRON", subtitle: "Left", value: pronationIndex(ble.leftReadings),
                       format: "%.2f", alert: pronationIndex(ble.leftReadings) > 1.3, alertLabel: "OVER",
                       textPrimary: textPrimary, textSecondary: textTertiary)
            metricDivider
            MetricTile(title: "PRON", subtitle: "Right", value: pronationIndex(ble.rightReadings),
                       format: "%.2f", alert: pronationIndex(ble.rightReadings) > 1.3, alertLabel: "OVER",
                       textPrimary: textPrimary, textSecondary: textTertiary)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(cardBorder, lineWidth: 1)
                )
        )
    }

    var metricDivider: some View {
        Rectangle()
            .fill(cardBorder)
            .frame(width: 1, height: 50)
    }

    // MARK: - Legend

    var legendBar: some View {
        HStack(spacing: 8) {
            Text("0%")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(textSecondary)

            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0.05, green: 0.15, blue: 0.3), location: 0),
                            .init(color: Color(red: 0.05, green: 0.4, blue: 0.25), location: 0.3),
                            .init(color: Color(red: 0.5, green: 0.85, blue: 0.1), location: 0.5),
                            .init(color: Color(red: 0.9, green: 0.5, blue: 0.05), location: 0.75),
                            .init(color: Color(red: 1.0, green: 0.15, blue: 0.1), location: 1.0),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 6)

            Text("200%")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(textSecondary)
        }
    }

    // MARK: - Motors

    var motorControls: some View {
        HStack(spacing: 12) {
            Button(action: { ble.buzzLeft() }) {
                HStack(spacing: 4) {
                    Image(systemName: "waveform.path")
                        .font(.system(size: 11))
                    Text("LEFT")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(buttonBg)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(buttonBorder, lineWidth: 1)
                )
            }
            .foregroundColor(buttonText)

            Button(action: { ble.buzzBoth() }) {
                HStack(spacing: 4) {
                    Image(systemName: "waveform.badge.exclamationmark")
                        .font(.system(size: 11))
                    Text("BOTH")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.12))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            }
            .foregroundColor(.red.opacity(0.85))

            Button(action: { ble.buzzRight() }) {
                HStack(spacing: 4) {
                    Image(systemName: "waveform.path")
                        .font(.system(size: 11))
                    Text("RIGHT")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(buttonBg)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(buttonBorder, lineWidth: 1)
                )
            }
            .foregroundColor(buttonText)
        }
    }

    // MARK: - Calculations

    func archIndex(_ r: [UInt16]) -> Double {
        let total = r.map { Double($0) }.reduce(0, +)
        guard total > 0 else { return 0 }
        return Double(r[2]) / total
    }

    func pronationIndex(_ r: [UInt16]) -> Double {
        let s = r.map { Double($0) }
        let total = s.reduce(0, +)
        guard total > 0 else { return 0 }
        let denom = s[1] + s[4]
        guard denom > 0 else { return 0 }
        return (s[0] + s[2] + s[3]) / denom
    }
}

// MARK: - Foot Heatmap

struct FootHeatmap: View {
    let values: [CGFloat]  // pre-normalized 0-1
    let positions: [HeatmapRenderer.SensorPosition]
    let isLeft: Bool
    let resolution: Int
    let label: String
    let outlineColor: Color
    let glowColor: Color
    let dotColor: Color
    let labelColor: Color

    var body: some View {
        VStack(spacing: 6) {
            Canvas { context, size in
                let footRect = CGRect(origin: .zero, size: size)
                let footPath = HeatmapRenderer.footPath(in: footRect, isLeft: isLeft)

                context.drawLayer { glow in
                    glow.addFilter(.blur(radius: 15))
                    glow.fill(footPath, with: .color(glowColor))
                }

                context.clip(to: footPath)

                let stepX = size.width / CGFloat(resolution)
                let stepY = size.height / CGFloat(resolution)

                for row in 0..<resolution {
                    for col in 0..<resolution {
                        let px = (CGFloat(col) + 0.5) / CGFloat(resolution)
                        let py = (CGFloat(row) + 0.5) / CGFloat(resolution)

                        let intensity = HeatmapRenderer.interpolate(
                            at: CGPoint(x: px, y: py),
                            values: values,
                            positions: positions
                        )

                        let rgb = ColorMap.uiColor(for: Double(intensity))
                        let color = Color(red: rgb.r, green: rgb.g, blue: rgb.b)

                        let rect = CGRect(
                            x: CGFloat(col) * stepX,
                            y: CGFloat(row) * stepY,
                            width: stepX + 1,
                            height: stepY + 1
                        )
                        context.fill(Path(rect), with: .color(color))
                    }
                }

                context.stroke(footPath, with: .color(outlineColor), lineWidth: 1.5)

                for (i, pos) in positions.enumerated() {
                    let center = CGPoint(x: pos.x * size.width, y: pos.y * size.height)
                    let intensity = Double(values[i])

                    let glowSize: CGFloat = intensity > 0.5 ? 14 : 10
                    let glowRect = CGRect(x: center.x - glowSize/2, y: center.y - glowSize/2,
                                          width: glowSize, height: glowSize)
                    context.fill(Path(ellipseIn: glowRect),
                                with: .color(ColorMap.color(for: intensity).opacity(0.4)))

                    let dotRect = CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)
                    context.fill(Path(ellipseIn: dotRect), with: .color(dotColor))
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(0.45, contentMode: .fit)

            Text(label)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(3)
                .foregroundColor(labelColor)
        }
    }
}

// MARK: - Metric Tile

struct MetricTile: View {
    let title: String
    let subtitle: String
    let value: Double
    let format: String
    let alert: Bool
    let alertLabel: String
    let textPrimary: Color
    let textSecondary: Color

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(textSecondary)
                if alert {
                    Text(alertLabel)
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundColor(.red)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(2)
                }
            }

            Text(String(format: format, value))
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(alert ? .red : textPrimary.opacity(0.85))

            Text(subtitle)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}
