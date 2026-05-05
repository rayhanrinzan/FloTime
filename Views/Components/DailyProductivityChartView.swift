import Charts
import SwiftUI

struct DailyProductivityChartView: View {
    let points: [ProductivityChartPoint]

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Time", point.timestamp),
                y: .value("Rating", point.rating)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(FloTimeTheme.primary)
            .lineStyle(StrokeStyle(lineWidth: 4, lineCap: .round))

            PointMark(
                x: .value("Time", point.timestamp),
                y: .value("Rating", point.rating)
            )
            .foregroundStyle(FloTimeTheme.primary)
        }
        .chartYScale(domain: 0...10)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 4)) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(FloTimeTheme.accent)
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 2, 4, 6, 8, 10])
        }
        .frame(height: 220)
    }
}
