//
//  ReportsView.swift
//  Pedisense
//
//  Created by Harry Pall on 2026-04-18.
//

import SwiftUI

struct ReportView: View {
    @ObservedObject var ble: BLEManager
    @ObservedObject var calibration: CalibrationService
    @Environment(\.colorScheme) var colorScheme

    @State private var report: String?
    @State private var isLoading = false
    @State private var error: String?

    let agentClient = AgentClient()

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
                            Text("Clinical Report")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(textPrimary)
                        }
                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "brain")
                                .font(.system(size: 10))
                            Text("Gemini")
                                .font(.system(size: 9, design: .monospaced))
                        }
                        .foregroundColor(.purple.opacity(0.6))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    if report == nil && !isLoading {
                        // Generate button
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.cyan.opacity(0.5))

                            Text("Generate a clinical report from your current sensor data to share with your podiatrist")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)

                            Button(action: generateReport) {
                                HStack(spacing: 8) {
                                    Image(systemName: "waveform.path.ecg")
                                        .font(.system(size: 16))
                                    Text("GENERATE REPORT")
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
                                Text("Connect to Pedisense to generate report")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.top, 40)
                    } else if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.purple)
                                .scaleEffect(1.2)
                            Text("Generating clinical report...")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(textSecondary)
                        }
                        .padding(.vertical, 60)
                    } else if let error = error {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 24))
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.center)
                            Button("Retry") { generateReport() }
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                        .padding(.vertical, 40)
                    } else if let report = report {
                        // Report content
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Report Generated")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(textPrimary)
                                Spacer()
                                Text(Date(), style: .date)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(textSecondary)
                            }

                            Divider().opacity(0.2)

                            Text(report)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(textPrimary.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
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

                        // Actions
                        HStack(spacing: 12) {
                            ShareLink(item: report) {
                                HStack(spacing: 4) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 12))
                                    Text("SHARE")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.cyan.opacity(0.12))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .foregroundColor(.cyan)

                            Button(action: { self.report = nil; self.error = nil }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 12))
                                    Text("NEW")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(cardBg)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(cardBorder, lineWidth: 1)
                                )
                            }
                            .foregroundColor(textPrimary.opacity(0.7))
                        }
                        .padding(.horizontal, 20)
                    }

                    Spacer().frame(height: 20)
                }
            }
        }
    }

    func generateReport() {
        isLoading = true
        error = nil

        let sessionData: [String: Any] = [
            "left_readings": ble.leftReadings.map { Int($0) },
            "right_readings": ble.rightReadings.map { Int($0) },
            "calibrated": calibration.isCalibrated,
            "left_baseline": calibration.leftBaseline,
            "right_baseline": calibration.rightBaseline,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        Task {
            do {
                let result = try await agentClient.generateReport(sessionData: sessionData)
                await MainActor.run {
                    report = result
                    isLoading = false
                }

                // Save to Supabase
                do {
                    try await SupabaseManager.shared.saveReport(
                        scanId: nil,
                        reportText: result
                    )
                } catch {
                    print("Failed to save report: \(error)")
                }
            }
        }
    }
}
