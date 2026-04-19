import SwiftUI
import Combine

class CalibrationService: ObservableObject {
    @Published var isCalibrated = false
    @Published var isCalibrating = false
    @Published var countdown: Int = 5
    @Published var leftBaseline: [Double] = Array(repeating: 0, count: 5)
    @Published var rightBaseline: [Double] = Array(repeating: 0, count: 5)

    private var frames: [[UInt16]] = []
    private var captureTimer: Timer?
    private var countdownTimer: Timer?

    func startCalibration(ble: BLEManager) {
        isCalibrating = true
        isCalibrated = false
        countdown = 5
        frames = []

        captureTimer = Timer.scheduledTimer(withTimeInterval: 0.066, repeats: true) { _ in
            let frame = ble.leftReadings + ble.rightReadings
            self.frames.append(frame)
        }

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.countdown -= 1
            if self.countdown <= 0 {
                self.finishCalibration()
            }
        }
    }

    private func finishCalibration() {
        captureTimer?.invalidate()
        countdownTimer?.invalidate()
        captureTimer = nil
        countdownTimer = nil
        isCalibrating = false

        guard !frames.isEmpty else { return }

        for i in 0..<5 {
            let leftSum = frames.reduce(0) { $0 + Int($1[i]) }
            let rightSum = frames.reduce(0) { $0 + Int($1[i + 5]) }
            leftBaseline[i] = Double(leftSum) / Double(frames.count)
            rightBaseline[i] = Double(rightSum) / Double(frames.count)
        }

        isCalibrated = true

        // Save locally
        UserDefaults.standard.set(leftBaseline, forKey: "pedisense_left_baseline")
        UserDefaults.standard.set(rightBaseline, forKey: "pedisense_right_baseline")
        UserDefaults.standard.set(true, forKey: "pedisense_calibrated")

        print("Calibration complete: \(frames.count) frames")
        print("Left baseline: \(leftBaseline.map { String(format: "%.0f", $0) })")
        print("Right baseline: \(rightBaseline.map { String(format: "%.0f", $0) })")

        // Also save to Supabase for cloud backup
        Task {
            do {
                try await SupabaseManager.shared.saveCalibration(
                    leftBaseline: leftBaseline,
                    rightBaseline: rightBaseline
                )
            } catch {
                print("Failed to save calibration to Supabase: \(error)")
            }
        }
    }

    func loadSavedCalibration() {
        guard UserDefaults.standard.bool(forKey: "pedisense_calibrated") else { return }
        if let left = UserDefaults.standard.array(forKey: "pedisense_left_baseline") as? [Double],
           let right = UserDefaults.standard.array(forKey: "pedisense_right_baseline") as? [Double],
           left.count == 5, right.count == 5 {
            leftBaseline = left
            rightBaseline = right
            isCalibrated = true
            print("Loaded calibration from UserDefaults")
        }
    }

    func reset() {
        captureTimer?.invalidate()
        countdownTimer?.invalidate()
        isCalibrated = false
        isCalibrating = false
        countdown = 5
        frames = []
        leftBaseline = Array(repeating: 0, count: 5)
        rightBaseline = Array(repeating: 0, count: 5)
        UserDefaults.standard.set(false, forKey: "pedisense_calibrated")
    }

    func normalizedLeft(_ readings: [UInt16]) -> [Double] {
        guard isCalibrated else { return readings.map { Double($0) } }
        return zip(readings, leftBaseline).map { reading, base in
            guard base > 0 else { return 0 }
            return (Double(reading) / base) * 100.0
        }
    }

    func normalizedRight(_ readings: [UInt16]) -> [Double] {
        guard isCalibrated else { return readings.map { Double($0) } }
        return zip(readings, rightBaseline).map { reading, base in
            guard base > 0 else { return 0 }
            return (Double(reading) / base) * 100.0
        }
    }
}
