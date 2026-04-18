import SwiftUI

struct ColorMap {
    static func color(for value: Double) -> Color {
        let clamped = min(max(value, 0), 1)

        if clamped < 0.2 {
            let t = clamped / 0.2
            return Color(
                red: 0.05 + t * 0.0,
                green: 0.08 + t * 0.15,
                blue: 0.18 + t * 0.15
            )
        } else if clamped < 0.4 {
            let t = (clamped - 0.2) / 0.2
            return Color(
                red: 0.05 + t * 0.0,
                green: 0.23 + t * 0.35,
                blue: 0.33 - t * 0.1
            )
        } else if clamped < 0.6 {
            let t = (clamped - 0.4) / 0.2
            return Color(
                red: 0.05 + t * 0.6,
                green: 0.58 + t * 0.32,
                blue: 0.23 - t * 0.18
            )
        } else if clamped < 0.8 {
            let t = (clamped - 0.6) / 0.2
            return Color(
                red: 0.65 + t * 0.30,
                green: 0.90 - t * 0.45,
                blue: 0.05
            )
        } else {
            let t = (clamped - 0.8) / 0.2
            return Color(
                red: 0.95 + t * 0.05,
                green: 0.45 - t * 0.35,
                blue: 0.05 + t * 0.05
            )
        }
    }

    static func uiColor(for value: Double) -> (r: Double, g: Double, b: Double) {
        let clamped = min(max(value, 0), 1)

        if clamped < 0.2 {
            let t = clamped / 0.2
            return (0.05 + t * 0.0, 0.08 + t * 0.15, 0.18 + t * 0.15)
        } else if clamped < 0.4 {
            let t = (clamped - 0.2) / 0.2
            return (0.05, 0.23 + t * 0.35, 0.33 - t * 0.1)
        } else if clamped < 0.6 {
            let t = (clamped - 0.4) / 0.2
            return (0.05 + t * 0.6, 0.58 + t * 0.32, 0.23 - t * 0.18)
        } else if clamped < 0.8 {
            let t = (clamped - 0.6) / 0.2
            return (0.65 + t * 0.30, 0.90 - t * 0.45, 0.05)
        } else {
            let t = (clamped - 0.8) / 0.2
            return (0.95 + t * 0.05, 0.45 - t * 0.35, 0.05 + t * 0.05)
        }
    }
}
