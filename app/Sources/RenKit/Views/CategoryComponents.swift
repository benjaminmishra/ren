import SwiftUI

// MARK: - Donut Chart Component
struct DonutChartView: View {
    let slices: [ChartSlice]
    var strokeWidth: CGFloat = 20

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: strokeWidth
                )

            ForEach(slices) { slice in
                PieSlice(startAngle: slice.startAngle, endAngle: slice.endAngle)
                    .stroke(
                        slice.category.color,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .butt)
                    )
                    .shadow(color: slice.category.color.opacity(0.40), radius: 5)
            }
        }
        .padding(10)
    }
}

struct PieSlice: Shape {
    var startAngle: Angle
    var endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}

// MARK: - Scanning Category Row
struct ScanningCategoryRow: View {
    let cat: CleanCategory
    let items: [CleanItem]
    let isCompleted: Bool
    let isCurrent: Bool

    var body: some View {
        let totalBytes = items.map(\.sizeBytes).sum()

        HStack(spacing: 10) {
            if isCurrent {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 15, height: 15)
            } else if isCompleted {
                ZStack {
                    Circle()
                        .strokeBorder(cat.color, lineWidth: 1.5)
                        .frame(width: 15, height: 15)
                    if !items.isEmpty {
                        Circle()
                            .fill(cat.color)
                            .frame(width: 7, height: 7)
                    }
                }
            } else {
                Circle()
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    .frame(width: 15, height: 15)
            }

            Text(cat.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isCompleted || isCurrent ? .white : Theme.textDimmed)

            Spacer()

            if isCurrent {
                Text("Scanning...")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.cyan)
            } else if isCompleted {
                Text(totalBytes > 0 ? totalBytes.formattedByteSize : "Clean")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(totalBytes > 0 ? cat.color : Theme.textMuted.opacity(0.6))
            } else {
                Text("Pending")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Theme.textMuted.opacity(0.4))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            LiquidGlassBackground(
                cornerRadius: 9,
                isSelected: isCurrent,
                accentColor: cat.color,
                intensity: isCurrent ? 1.2 : 0.8
            )
        )
    }
}

// MARK: - Liquid Glass Category Card
struct LiquidGlassCategoryCard: View {
    let summary: CategorySummary
    let isSelected: Bool
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? summary.category.color : Color.white.opacity(0.25),
                            lineWidth: 1.5
                        )
                        .frame(width: 15, height: 15)

                    if isSelected {
                        Circle()
                            .fill(summary.category.color)
                            .frame(width: 7, height: 7)
                            .shadow(color: summary.category.color.opacity(0.85), radius: 4)
                    }
                }

                Text(summary.category.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : Theme.textSecondary)

                Spacer()

                Text(summary.formattedSize)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(isSelected ? summary.category.color : Theme.textDimmed)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                LiquidGlassBackground(
                    cornerRadius: 9,
                    isSelected: isSelected,
                    accentColor: summary.category.color,
                    intensity: isHovered ? 1.3 : 1.0
                )
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.75), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
