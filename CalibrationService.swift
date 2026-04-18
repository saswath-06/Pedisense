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
        
        // Capture frames at ~15Hz
        captureTimer = Timer.scheduledTimer(withTimeInterval: 0.066, repeats: true) { _ in
            let frame = ble.leftReadings + ble.rightReadings
            self.frames.append(frame)
        }
        
        // Countdown
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
        
        print("Calibration complete: \(frames.count) frames")
        print("Left baseline: \(leftBaseline.map { String(format: "%.0f", $0) })")
        print("Right baseline: \(rightBaseline.map { String(format: "%.0f", $0) })")
        
        // Save to Supabase
        Task {
            do {
                try await SupabaseManager.shared.saveCalibration(
                    leftBaseline: leftBaseline,
                    rightBaseline: rightBaseline
                )
            } catch {
                print("Failed to save calibration: \(error)")
            }
        }
    }
    
    func loadSavedCalibration() {
        Task {
            do {
                if let saved = try await SupabaseManager.shared.loadLatestCalibration() {
                    await MainActor.run {
                        leftBaseline = saved.left
                        rightBaseline = saved.right
                        isCalibrated = true
                        print("Loaded saved calibration from Supabase")
                    }
                }
            } catch {
                print("No saved calibration found: \(error)")
            }
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
    }
    
}
