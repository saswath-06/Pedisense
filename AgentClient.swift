//
//  AgentClient.swift
//  Pedisense
//
//  Created by Harry Pall on 2026-04-18.
//E

import Foundation

class AgentClient {
    // Replace with your actual Railway URL
    let baseURL = "https://pedisense-production.up.railway.app"

    struct AnalysisResponse: Decodable {
        let analysis: String
        let metrics: MetricsWrapper
        let exercises: [Exercise]
    }

    struct MetricsWrapper: Decodable {
        let left: FootData
        let right: FootData
    }

    struct FootData: Decodable {
        let side: String
        let pronation_index: Double
        let arch_index: Double
        let heel_centering: Double
        let forefoot_balance: Double
        let total_load: Int
    }

    struct Exercise: Decodable {
        let name: String
        let description: String
        let sets: Int
        let frequency: String
    }

    struct ReportResponse: Decodable {
        let report: String
    }

    func analyzeScan(left: [UInt16], right: [UInt16]) async throws -> AnalysisResponse {
        let url = URL(string: "\(baseURL)/analyze")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "left_readings": left.map { Int($0) },
            "right_readings": right.map { Int($0) }
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AgentError.serverError
        }

        return try JSONDecoder().decode(AnalysisResponse.self, from: data)
    }

    func generateReport(sessionData: [String: Any]) async throws -> String {
        let url = URL(string: "\(baseURL)/report")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        request.httpBody = try JSONSerialization.data(withJSONObject: sessionData)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AgentError.serverError
        }

        let result = try JSONDecoder().decode(ReportResponse.self, from: data)
        return result.report
    }

    enum AgentError: Error, LocalizedError {
        case serverError

        var errorDescription: String? {
            switch self {
            case .serverError: return "Agent server returned an error"
            }
        }
    }
}  
