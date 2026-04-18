import SwiftUI
import Charts

struct TrendsView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var scans: [ScanRecord] = []
    @State private var isLoading = true
    @State private var hasData = false

    var bgColor: Color {
        colorScheme == .dark
            ? Color(red: 0.06, green: 0.06, blue: 0.09)
            : Color(red: 0.96, green: 0.96, blue: 0.98)
    }

    var textPrimary: Color { colorScheme == .dark ? .white : .black }
    var textSecondary: Color { colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.45) }
    var cardBg: Color { colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03) }
    var cardBorder: Color { colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08) }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PEDISENSE")
                                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                                .tracking(4)
                                .foregroundColor(textPrimary.opacity(0.9))
                            Text("Trends")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(textPrimary)
                        }
                        Spacer()

                        Text("\(scans.count) scans")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(textSecondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    if isLoading {
                        ProgressView()
                            .tint(.cyan)
                            .padding(.top, 60)
                    } else if scans.count < 2 {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 48))
                                .foregroundColor(.cyan.opacity(0.4))

                            Text("Not enough data yet")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(textPrimary)

                            Text("Complete at least 2 diagnostic scans to see trends. Each scan is saved automatically.")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .padding(.top, 40)
                    } else {
                        // Arch index chart
                        trendChart(
                            title: "ARCH INDEX (LEFT)",
                            data: scans.reversed().enumerated().compactMap { i, s in
                                guard let v = s.left_arch_index else { return nil }
                                return TrendPoint(day: i, value: v)
                            },
                            thresholdValue: 0.12,
                            thresholdLabel: "Flat foot threshold",
                            color: .red,
                            yRange: 0...0.30
                        )

                        trendChart(
                            title: "ARCH INDEX (RIGHT)",
                            data: scans.reversed().enumerated().compactMap { i, s in
                                guard let v = s.right_arch_index else { return nil }
                                return TrendPoint(day: i, value: v)
                            },
                            thresholdValue: 0.12,
                            thresholdLabel: "Flat foot threshold",
                            color: .red,
                            yRange: 0...0.30
                        )

                        trendChart(
                            title: "PRONATION (LEFT)",
                            data: scans.reversed().enumerated().compactMap { i, s in
                                guard let v = s.left_pronation else { return nil }
                                return TrendPoint(day: i, value: v)
                            },
                            thresholdValue: 1.3,
                            thresholdLabel: "Overpronation threshold",
                            color: .orange,
                            yRange: 0.5...2.0
                        )

                        trendChart(
                            title: "PRONATION (RIGHT)",
                            data: scans.reversed().enumerated().compactMap { i, s in
                                guard let v = s.right_pronation else { return nil }
                                return TrendPoint(day: i, value: v)
                            },
                            thresholdValue: 1.3,
                            thresholdLabel: "Overpronation threshold",
                            color: .orange,
                            yRange: 0.5...2.0
                        )
                    }

                    Spacer().frame(height: 20)
                }
            }
        }
        .onAppear {
            loadScans()
        }
    }

    func loadScans() {
        Task {
            do {
                let loaded = try await SupabaseManager.shared.loadScans(limit: 30)
                await MainActor.run {
                    scans = loaded
                    isLoading = false
                }
            } catch {
                print("Failed to load scans: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }

    func trendChart(title: String, data: [TrendPoint], thresholdValue: Double, thresholdLabel: String, color: Color, yRange: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(2)
                .foregroundColor(textSecondary)

            if data.isEmpty {
                Text("No data")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(textSecondary)
                    .frame(height: 150)
            } else {
                Chart {
                    ForEach(data) { point in
                        LineMark(
                            x: .value("Scan", point.day),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(color)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Scan", point.day),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [color.opacity(0.2), color.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Scan", point.day),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(color)
                        .symbolSize(20)
                    }

                    RuleMark(y: .value("Threshold", thresholdValue))
                        .foregroundStyle(.white.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .annotation(position: .top, alignment: .leading) {
                            Text(thresholdLabel)
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(textSecondary)
                        }
                }
                .chartYScale(domain: yRange)
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("#\(v + 1)")
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(textSecondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(format: "%.2f", v))
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(textSecondary)
                            }
                        }
                    }
                }
                .frame(height: 180)
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
}

struct TrendPoint: Identifiable {
    let id = UUID()
    let day: Int
    let value: Double
}
