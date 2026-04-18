import CoreBluetooth
import Combine

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var isConnected = false
    @Published var leftReadings: [UInt16] = Array(repeating: 0, count: 5)
    @Published var rightReadings: [UInt16] = Array(repeating: 0, count: 5)

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var motorCharacteristic: CBCharacteristic?
    private var lastUIUpdate: Date = Date.distantPast

    // Alert engine reference for background evaluation
    var alertEngine: AlertEngine?

    let serviceUUID = CBUUID(string: "12345678-1234-1234-1234-123456789abc")
    let sensorCharUUID = CBUUID(string: "abcdefab-1234-1234-1234-abcdefabcdef")
    let motorCharUUID = CBUUID(string: "abcdefab-1234-1234-1234-abcdefab0002")

    override init() {
        super.init()
        // Restore identifier allows iOS to relaunch app for BLE events
        centralManager = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [CBCentralManagerOptionRestoreIdentifierKey: "PedisenseCentralManager"]
        )
    }

    // MARK: - Motor Control

    func buzzLeft(duration: UInt8 = 50) {
        sendMotorCommand(left: duration, right: 0)
    }

    func buzzRight(duration: UInt8 = 50) {
        sendMotorCommand(left: 0, right: duration)
    }

    func buzzBoth(duration: UInt8 = 50) {
        sendMotorCommand(left: duration, right: duration)
    }

    private func sendMotorCommand(left: UInt8, right: UInt8) {
        guard let char = motorCharacteristic, let periph = peripheral else {
            print("Motor write failed: not connected or characteristic not found")
            return
        }
        let data = Data([left, right])
        periph.writeValue(data, for: char, type: .withResponse)
        print("Motor command sent: left=\(left) right=\(right)")
    }

    // MARK: - Central Manager

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("Bluetooth state: \(central.state.rawValue)")
        if central.state == .poweredOn {
            print("Starting scan for Pedisense...")
            centralManager.scanForPeripherals(withServices: [serviceUUID])
        }
    }

    // Background state restoration
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        print("Restoring BLE state from background")
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for p in peripherals {
                self.peripheral = p
                p.delegate = self
                if p.state == .connected {
                    isConnected = true
                    p.discoverServices([serviceUUID])
                    print("Restored connected peripheral: \(p.name ?? "unknown")")
                }
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        print("Found device: \(peripheral.name ?? "unknown")")
        self.peripheral = peripheral
        peripheral.delegate = self
        centralManager.stopScan()
        centralManager.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "unknown")")
        isConnected = true
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect: \(error?.localizedDescription ?? "unknown error")")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected: \(error?.localizedDescription ?? "clean disconnect")")
        isConnected = false
        motorCharacteristic = nil
        centralManager.scanForPeripherals(withServices: [serviceUUID])
    }

    // MARK: - Peripheral

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Service discovery error: \(error.localizedDescription)")
            return
        }
        print("Services found: \(peripheral.services?.count ?? 0)")
        guard let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else {
            print("Target service not found!")
            return
        }
        peripheral.discoverCharacteristics([sensorCharUUID, motorCharUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Characteristic discovery error: \(error.localizedDescription)")
            return
        }
        for char in service.characteristics ?? [] {
            if char.uuid == sensorCharUUID {
                peripheral.setNotifyValue(true, for: char)
                print("Subscribed to sensor notifications")
            } else if char.uuid == motorCharUUID {
                motorCharacteristic = char
                print("Motor characteristic found")
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error { return }
        guard let data = characteristic.value, data.count == 20 else { return }

        var readings: [UInt16] = []
        for i in stride(from: 0, to: 20, by: 2) {
            let value = UInt16(data[i]) << 8 | UInt16(data[i + 1])
            readings.append(value)
        }

        let left = Array(readings[0..<5])
        let right = Array(readings[5..<10])

        // Always evaluate alerts (works in background)
        alertEngine?.evaluate(leftReadings: left, rightReadings: right)

        // Only update UI at ~15Hz when in foreground
        let now = Date()
        if now.timeIntervalSince(lastUIUpdate) >= 0.066 {
            lastUIUpdate = now
            DispatchQueue.main.async {
                self.leftReadings = left
                self.rightReadings = right
            }
        }
    }
}
