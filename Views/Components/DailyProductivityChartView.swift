import Charts
import SwiftUI

struct DailyProductivityChartView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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
        .chartXScale(domain: chartDomain)
        .chartYScale(domain: 0...10)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: axisStrideHours)) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(FloTimeTheme.accent)
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 2, 4, 6, 8, 10])
        }
        .frame(height: 220)
    }

    private var axisStrideHours: Int {
        horizontalSizeClass == .compact ? 3 : 2
    }

    private var chartDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        let referenceDate = points.first?.timestamp ?? .now
        let start = calendar.startOfDay(for: referenceDate)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return start...end
    }
}
