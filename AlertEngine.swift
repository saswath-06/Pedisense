import SwiftUI
import UserNotifications
import Combine

class AlertEngine: ObservableObject {
    @Published var activeAlerts: [ZoneAlert] = []
    @Published var isMonitoring = false

    private var zonePressureTimers: [Int: Date] = [:]
    private let bleManager: BLEManager

    var adcThreshold: UInt16 = 2800
    var durationLimit: TimeInterval = 15

    let zoneNames = ["1st Met", "5th Met", "Midfoot", "Med Heel", "Lat Heel"]

    struct ZoneAlert: Identifiable {
        let id = UUID()
        let zone: String
        let foot: String
        let duration: TimeInterval
        let timestamp: Date
    }

    init(bleManager: BLEManager) {
        self.bleManager = bleManager
        requestNotificationPermission()
    }

    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.delegate = NotificationDelegate.shared
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("Notifications granted: \(granted)")
        }
    }

    func startMonitoring() {
        isMonitoring = true
        zonePressureTimers.removeAll()
        activeAlerts.removeAll()
        print("Monitoring started: threshold=\(adcThreshold), duration=\(Int(durationLimit))s")
    }

    func stopMonitoring() {
        isMonitoring = false
        zonePressureTimers.removeAll()
        print("Monitoring stopped")
    }

    func evaluate(leftReadings: [UInt16], rightReadings: [UInt16]) {
        guard isMonitoring else { return }

        let allReadings = leftReadings + rightReadings
        let now = Date()

        for (i, value) in allReadings.enumerated() {
            if value > adcThreshold {
                if let start = zonePressureTimers[i] {
                    let elapsed = now.timeIntervalSince(start)
                    if elapsed >= durationLimit {
                        let foot = i < 5 ? "Left" : "Right"
                        let zone = zoneNames[i % 5]

                        print("ALERT FIRED: \(foot) \(zone) after \(Int(elapsed))s")

                        let alert = ZoneAlert(
                            zone: zone,
                            foot: foot,
                            duration: elapsed,
                            timestamp: now
                        )
                        activeAlerts.insert(alert, at: 0)

                        if activeAlerts.count > 10 {
                            activeAlerts.removeLast()
                        }

                        if i < 5 {
                            bleManager.buzzLeft(duration: 80)
                        } else {
                            bleManager.buzzRight(duration: 80)
                        }

                        sendNotification(zone: zone, foot: foot)
                        // Save to Supabase
                        Task {
                            do {
                                try await SupabaseManager.shared.saveAlert(
                                    zone: zone, foot: foot, duration: elapsed
                                )
                            } catch {
                                print("Failed to save alert: \(error)")
                            }
                        }

                        zonePressureTimers.removeValue(forKey: i)
                    }
                } else {
                    print("Timer started: zone \(i), value \(value)")
                    zonePressureTimers[i] = now
                }
            } else {
                if zonePressureTimers[i] != nil {
                    print("Timer reset: zone \(i), value dropped to \(value)")
                }
                zonePressureTimers.removeValue(forKey: i)
            }
        }
    }

    private func sendNotification(zone: String, foot: String) {
        let content = UNMutableNotificationContent()
        content.title = "Pressure Alert"
        content.body = "Sustained pressure on \(foot) \(zone). Shift your weight."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func timerProgress(for zoneIndex: Int) -> Double {
        guard let start = zonePressureTimers[zoneIndex] else { return 0 }
        let elapsed = Date().timeIntervalSince(start)
        return min(elapsed / durationLimit, 1.0)
    }
}

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
