//
//  SupabaseManager.swift
//  Pedisense
//
//  Created by Harry Pall on 2026-04-18.
//

import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    // Device ID persists across app launches as anonymous identity
    var deviceId: String {
        if let existing = UserDefaults.standard.string(forKey: "pedisense_device_id") {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "pedisense_device_id")
        return newId
    }

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://xkvsjlvikvwiyfzcxutp.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhrdnNqbHZpa3Z3aXlmemN4dXRwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY1MzE1MjUsImV4cCI6MjA5MjEwNzUyNX0.Qnn1sjZRuh-6UB9SUMyzg_UYMFhiQIxmYKPu5EsnE8w"
        )
    }

    // MARK: - Calibration

    func saveCalibration(leftBaseline: [Double], rightBaseline: [Double]) async throws {
        let row: [String: AnyJSON] = [
            "device_id": .string(deviceId),
            "left_baseline": .array(leftBaseline.map { .double($0) }),
            "right_baseline": .array(rightBaseline.map { .double($0) })
        ]
        try await client.from("calibrations").insert(row).execute()
        print("Calibration saved to Supabase")
    }

    func loadLatestCalibration() async throws -> (left: [Double], right: [Double])? {
        struct CalibrationRow: Decodable {
            let left_baseline: [Double]
            let right_baseline: [Double]
        }

        let response: [CalibrationRow] = try await client.from("calibrations")
            .select()
            .eq("device_id", value: deviceId)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value

        guard let latest = response.first else { return nil }
        return (left: latest.left_baseline, right: latest.right_baseline)
    }

    // MARK: - Scans

    func saveScan(
        leftReadings: [UInt16], rightReadings: [UInt16],
        leftMetrics: FootMetrics, rightMetrics: FootMetrics,
        aiAnalysis: String?, exercises: [[String: String]]?
    ) async throws -> String {
        let scanId = UUID().uuidString

        var row: [String: AnyJSON] = [
            "id": .string(scanId),
            "device_id": .string(deviceId),
            "left_readings": .array(leftReadings.map { .double(Double($0)) }),
            "right_readings": .array(rightReadings.map { .double(Double($0)) }),
            "left_arch_index": .double(leftMetrics.archIndex),
            "right_arch_index": .double(rightMetrics.archIndex),
            "left_pronation": .double(leftMetrics.pronationIndex),
            "right_pronation": .double(rightMetrics.pronationIndex),
            "left_heel_centering": .double(leftMetrics.heelCentering),
            "right_heel_centering": .double(rightMetrics.heelCentering),
            "left_forefoot_balance": .double(leftMetrics.forefootBalance),
            "right_forefoot_balance": .double(rightMetrics.forefootBalance)
        ]

        if let analysis = aiAnalysis {
            row["ai_analysis"] = .string(analysis)
        }

        try await client.from("scans").insert(row).execute()
        print("Scan saved to Supabase: \(scanId)")
        return scanId
    }

    func loadScans(limit: Int = 30) async throws -> [ScanRecord] {
        let response: [ScanRecord] = try await client.from("scans")
            .select()
            .eq("device_id", value: deviceId)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return response
    }

    // MARK: - Reports

    func saveReport(scanId: String?, reportText: String) async throws {
        var row: [String: AnyJSON] = [
            "device_id": .string(deviceId),
            "report_text": .string(reportText)
        ]
        if let scanId = scanId {
            row["scan_id"] = .string(scanId)
        }

        try await client.from("reports").insert(row).execute()
        print("Report saved to Supabase")
    }

    func loadReports() async throws -> [ReportRecord] {
        let response: [ReportRecord] = try await client.from("reports")
            .select()
            .eq("device_id", value: deviceId)
            .order("created_at", ascending: false)
            .limit(20)
            .execute()
            .value

        return response
    }

    // MARK: - Alerts

    func saveAlert(zone: String, foot: String, duration: Double) async throws {
        let row: [String: AnyJSON] = [
            "device_id": .string(deviceId),
            "zone": .string(zone),
            "foot": .string(foot),
            "duration": .double(duration)
        ]
        try await client.from("alerts").insert(row).execute()
        print("Alert saved to Supabase")
    }
}

// MARK: - Data Models

struct ScanRecord: Decodable, Identifiable {
    let id: String
    let created_at: String
    let left_arch_index: Double?
    let right_arch_index: Double?
    let left_pronation: Double?
    let right_pronation: Double?
    let left_heel_centering: Double?
    let right_heel_centering: Double?
    let ai_analysis: String?
}

struct ReportRecord: Decodable, Identifiable {
    let id: String
    let created_at: String
    let report_text: String
}
