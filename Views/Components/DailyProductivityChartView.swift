import Charts
import SwiftUI

struct DailyProductivityChartView: View {
    let points: [HourlyProductivityPoint]

    var body: some View {
        Chart(points) { point in
            AreaMark(
                x: .value("Hour", point.hour),
                y: .value("Rating", point.averageRating)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [FloTimeTheme.primary.opacity(0.35), FloTimeTheme.secondary.opacity(0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Hour", point.hour),
                y: .value("Rating", point.averageRating)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(FloTimeTheme.primary)
            .lineStyle(StrokeStyle(lineWidth: 4, lineCap: .round))

            PointMark(
                x: .value("Hour", point.hour),
                y: .value("Rating", point.averageRating)
            )
            .foregroundStyle(FloTimeTheme.primary)
        }
        .chartYScale(domain: 0...10)
        .chartXAxis {
            AxisMarks(values: .stride(by: 4)) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(FloTimeTheme.accent)
                AxisValueLabel {
                    if let hour = $0.as(Int.self) {
                        Text("\(hour)")
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 2, 4, 6, 8, 10])
        }
        .frame(height: 220)
    }
}
