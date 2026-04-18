//
//  BiomechanicsAnalyzer.swift
//  Pedisense
//
//  Created by Harry Pall on 2026-04-18.
//

import Foundation

struct FootMetrics {
    let pronationIndex: Double
    let archIndex: Double
    let heelCentering: Double
    let forefootBalance: Double

    var flatFootFlag: Bool { archIndex > 0.12 }
    var overpronationFlag: Bool { pronationIndex > 1.3 }
}

struct BiomechanicsAnalyzer {
    static func analyze(readings: [UInt16]) -> FootMetrics {
        let s = readings.map { Double($0) }
        let total = s.reduce(0, +)

        guard total > 0 else {
            return FootMetrics(
                pronationIndex: 0,
                archIndex: 0,
                heelCentering: 0.5,
                forefootBalance: 0.5
            )
        }

        let pronation: Double = {
            let denom = s[1] + s[4]
            guard denom > 0 else { return 0 }
            return (s[0] + s[2] + s[3]) / denom
        }()

        return FootMetrics(
            pronationIndex: pronation,
            archIndex: s[2] / total,
            heelCentering: s[3] / max(s[3] + s[4], 1),
            forefootBalance: s[0] / max(s[0] + s[1], 1)
        )
    }
}
