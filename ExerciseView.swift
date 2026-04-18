//
//  ExerciseView.swift
//  Pedisense
//
//  Created by Harry Pall on 2026-04-18.
//

import SwiftUI
import Combine

struct ExerciseView: View {
    @ObservedObject var ble: BLEManager
    @ObservedObject var calibration: CalibrationService
    @Environment(\.colorScheme) var colorScheme

    @State private var selectedExercise: ExerciseType = .shortFoot
    @State private var isActive = false
    @State private var score: Double = 0
    @State private var bestScore: Double = 0
    @State private var sessionScores: [Double] = []

    enum ExerciseType: String, CaseIterable {
        case shortFoot = "Short Foot"
        case heelCenter = "Heel Centering"
        case forefootBalance = "Forefoot Balance"

        var description: String {
            switch self {
            case .shortFoot: return "Activate your arch by pulling the ball of your foot toward your heel without curling your toes. Watch the midfoot sensor decrease."
            case .heelCenter: return "Stand on one foot and center your weight evenly across the heel. Watch heel centering approach 0.50."
            case .forefootBalance: return "Shift weight between the big toe and pinky toe side of your forefoot. Try to hit the green target zone."
            }
        }

        var targetZone: String {
            switch self {
            case .shortFoot: return "Medial Midfoot"
            case .heelCenter: return "Heel (Med + Lat)"
            case .forefootBalance: return "1st + 5th Metatarsal"
            }
        }

        var icon: String {
            switch self {
            case .shortFoot: return "arrow.down.to.line"
            case .heelCenter: return "circle.dotted"
            case .forefootBalance: return "arrow.left.arrow.right"
            }
        }
    }

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
                            Text("Exercise Biofeedback")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(textPrimary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    // Exercise picker
                    VStack(spacing: 8) {
                        ForEach(ExerciseType.allCases, id: \.self) { ex in
                            Button(action: { selectedExercise = ex }) {
                                HStack(spacing: 10) {
                                    Image(systemName: ex.icon)
                                        .font(.system(size: 16))
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ex.rawValue)
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        Text("Target: \(ex.targetZone)")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(textSecondary)
                                    }
                                    Spacer()
                                    if selectedExercise == ex {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.cyan)
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedExercise == ex ? Color.cyan.opacity(0.08) : cardBg)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(selectedExercise == ex ? Color.cyan.opacity(0.3) : cardBorder, lineWidth: 1)
                                        )
                                )
                            }
                            .foregroundColor(textPrimary)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Instructions
                    Text(selectedExercise.description)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)

                    // Live score gauge
                    liveScoreGauge

                    // Start/Stop
                    Button(action: {
                        if isActive {
                            isActive = false
                        } else {
                            isActive = true
                            bestScore = 0
                            sessionScores = []
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: isActive ? "stop.fill" : "play.fill")
                                .font(.system(size: 14))
                            Text(isActive ? "STOP" : "START EXERCISE")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isActive ? Color.red.opacity(0.15) : Color.cyan.opacity(0.15))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isActive ? Color.red.opacity(0.4) : Color.cyan.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .foregroundColor(isActive ? .red : .cyan)
                    .padding(.horizontal, 20)
                    .disabled(!ble.isConnected)

                    // Best score
                    if bestScore > 0 {
                        HStack {
                            Image(systemName: "trophy.fill")
                                .foregroundColor(.yellow)
                            Text("Best: \(Int(bestScore))%")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.yellow)
                        }
                    }

                    Spacer().frame(height: 20)
                }
            }
        }
        .onChange(of: ble.leftReadings) {
            if isActive {
                updateScore()
            }
        }
    }

    var liveScoreGauge: some View {
        ZStack {
            Circle()
                .stroke(cardBorder, lineWidth: 8)
                .frame(width: 150, height: 150)

            Circle()
                .trim(from: 0, to: min(score / 100.0, 1.0))
                .stroke(
                    scoreColor,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 150, height: 150)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.2), value: score)

            VStack(spacing: 2) {
                Text("\(Int(score))")
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundColor(scoreColor)
                Text("SCORE")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(textSecondary)
            }
        }
        .padding(.vertical, 10)
    }

    var scoreColor: Color {
        if score < 30 { return .red }
        if score < 60 { return .orange }
        if score < 80 { return .yellow }
        return .green
    }

    func updateScore() {
        let left = ble.leftReadings.map { Double($0) }
        let right = ble.rightReadings.map { Double($0) }

        let newScore: Double

        switch selectedExercise {
        case .shortFoot:
            // Goal: minimize midfoot load relative to total
            let leftTotal = left.reduce(0, +)
            let rightTotal = right.reduce(0, +)
            let totalLoad = leftTotal + rightTotal
            guard totalLoad > 0 else { return }
            let midfootLoad = (left[2] + right[2]) / totalLoad
            // Lower midfoot = better. 0% midfoot = 100 score, 20%+ midfoot = 0 score
            newScore = max(0, min(100, (1.0 - midfootLoad / 0.20) * 100))

        case .heelCenter:
            // Goal: heel centering close to 0.50 on both feet
            let leftHC = left[3] / max(left[3] + left[4], 1)
            let rightHC = right[3] / max(right[3] + right[4], 1)
            let leftDev = abs(leftHC - 0.5)
            let rightDev = abs(rightHC - 0.5)
            let avgDev = (leftDev + rightDev) / 2.0
            // 0 deviation = 100 score, 0.3+ deviation = 0 score
            newScore = max(0, min(100, (1.0 - avgDev / 0.3) * 100))

        case .forefootBalance:
            // Goal: forefoot balance close to 0.60
            let leftFB = left[0] / max(left[0] + left[1], 1)
            let rightFB = right[0] / max(right[0] + right[1], 1)
            let leftDev = abs(leftFB - 0.60)
            let rightDev = abs(rightFB - 0.60)
            let avgDev = (leftDev + rightDev) / 2.0
            newScore = max(0, min(100, (1.0 - avgDev / 0.3) * 100))
        }

        score = newScore
        if newScore > bestScore {
            bestScore = newScore
        }
        sessionScores.append(newScore)
    }
}
