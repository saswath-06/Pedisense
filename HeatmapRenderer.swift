import SwiftUI

struct HeatmapRenderer {
    struct SensorPosition {
        let x: CGFloat
        let y: CGFloat
    }

    static let leftSensorPositions: [SensorPosition] = [
        SensorPosition(x: 0.35, y: 0.15),
        SensorPosition(x: 0.70, y: 0.20),
        SensorPosition(x: 0.30, y: 0.50),
        SensorPosition(x: 0.65, y: 0.85),
        SensorPosition(x: 0.35, y: 0.85),
    ]

    static let rightSensorPositions: [SensorPosition] = [
        SensorPosition(x: 0.30, y: 0.20),
        SensorPosition(x: 0.65, y: 0.15),
        SensorPosition(x: 0.70, y: 0.50),
        SensorPosition(x: 0.35, y: 0.85),
        SensorPosition(x: 0.65, y: 0.85),
    ]

    static func interpolate(at point: CGPoint, values: [CGFloat], positions: [SensorPosition]) -> CGFloat {
        var weightedSum: CGFloat = 0
        var totalWeight: CGFloat = 0

        for (i, sensor) in positions.enumerated() {
            let dx = point.x - sensor.x
            let dy = point.y - sensor.y
            let dist = sqrt(dx * dx + dy * dy)
            let weight = 1.0 / max(dist * dist, 0.001)
            weightedSum += weight * values[i]
            totalWeight += weight
        }

        return weightedSum / totalWeight
    }

    static func footPath(in rect: CGRect, isLeft: Bool) -> Path {
        let w = rect.width
        let h = rect.height

        var path = Path()

        if isLeft {
            path.move(to: CGPoint(x: w * 0.45, y: h * 0.02))
            path.addCurve(
                to: CGPoint(x: w * 0.15, y: h * 0.12),
                control1: CGPoint(x: w * 0.25, y: h * 0.0),
                control2: CGPoint(x: w * 0.15, y: h * 0.05)
            )
            path.addCurve(
                to: CGPoint(x: w * 0.20, y: h * 0.45),
                control1: CGPoint(x: w * 0.10, y: h * 0.20),
                control2: CGPoint(x: w * 0.12, y: h * 0.35)
            )
            path.addCurve(
                to: CGPoint(x: w * 0.25, y: h * 0.75),
                control1: CGPoint(x: w * 0.22, y: h * 0.55),
                control2: CGPoint(x: w * 0.20, y: h * 0.65)
            )
            path.addCurve(
                to: CGPoint(x: w * 0.50, y: h * 0.98),
                control1: CGPoint(x: w * 0.28, y: h * 0.85),
                control2: CGPoint(x: w * 0.35, y: h * 0.97)
            )
            path.addCurve(
                to: CGPoint(x: w * 0.80, y: h * 0.75),
                control1: CGPoint(x: w * 0.65, y: h * 0.97),
                control2: CGPoint(x: w * 0.75, y: h * 0.88)
            )
            path.addCurve(
                to: CGPoint(x: w * 0.85, y: h * 0.25),
                control1: CGPoint(x: w * 0.85, y: h * 0.60),
                control2: CGPoint(x: w * 0.88, y: h * 0.40)
            )
            path.addCurve(
                to: CGPoint(x: w * 0.45, y: h * 0.02),
                control1: CGPoint(x: w * 0.80, y: h * 0.10),
                control2: CGPoint(x: w * 0.65, y: h * 0.02)
            )
        } else {
            path.move(to: CGPoint(x: w * 0.55, y: h * 0.02))
            path.addCurve(
                to: CGPoint(x: w * 0.85, y: h * 0.12),
                control1: CGPoint(x: w * 0.75, y: h * 0.0),
                control2: CGPoint(x: w * 0.85, y: h * 0.05)
            )
            path.addCurve(
                to: CGPoint(x: w * 0.80, y: h * 0.45),
                control1: CGPoint(x: w * 0.90, y: h * 0.20),
                control2: CGPoint(x: w * 0.88, y: h * 0.35)
            )
            path.addCurve(
                to: CGPoint(x: w * 0.75, y: h * 0.75),
                control1: CGPoint(x: w * 0.78, y: h * 0.55),
                control2: CGPoint(x: w * 0.80, y: h * 0.65)
            )
            path.addCurve(
                to: CGPoint(x: w * 0.50, y: h * 0.98),
                control1: CGPoint(x: w * 0.72, y: h * 0.85),
                control2: CGPoint(x: w * 0.65, y: h * 0.97)
            )
            path.addCurve(
                to: CGPoint(x: w * 0.20, y: h * 0.75),
                control1: CGPoint(x: w * 0.35, y: h * 0.97),
                control2: CGPoint(x: w * 0.25, y: h * 0.88)
            )
            path.addCurve(
                to: CGPoint(x: w * 0.15, y: h * 0.25),
                control1: CGPoint(x: w * 0.15, y: h * 0.60),
                control2: CGPoint(x: w * 0.12, y: h * 0.40)
            )
            path.addCurve(
                to: CGPoint(x: w * 0.55, y: h * 0.02),
                control1: CGPoint(x: w * 0.20, y: h * 0.10),
                control2: CGPoint(x: w * 0.35, y: h * 0.02)
            )
        }

        path.closeSubpath()
        return path
    }
}
