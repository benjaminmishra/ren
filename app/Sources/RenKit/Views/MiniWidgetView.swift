import SwiftUI

struct MiniWidgetView: View {
    @ObservedObject var vm: CleanerViewModel
    let onExpand: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                RenLogoMark(size: 13)

                Text("Ren")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.88))

                Spacer()

                Button(action: onExpand) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.textMuted)
                        .padding(4)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Expand to Dashboard")
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            ZStack {
                DonutChartView(slices: vm.chartSlices, strokeWidth: 16)
                    .frame(width: 120, height: 120)

                VStack(spacing: 1) {
                    Text(vm.formattedSelectedSize)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Cleanable")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.cyan)
                        .textCase(.uppercase)
                }
            }
            .padding(.vertical, 4)

            if vm.items.isEmpty {
                LiquidGlassButton(
                    title: "Scan",
                    icon: "sparkles",
                    gradientColors: Theme.scanGradient,
                    isEnabled: vm.state != .scanning,
                    height: 28,
                    action: { vm.startScan() }
                )
                .padding(.horizontal, 16)
            } else {
                LiquidGlassButton(
                    title: "Clean \(vm.formattedSelectedSize)",
                    icon: "trash.fill",
                    gradientColors: Theme.trashGradient,
                    isEnabled: vm.selectedBytes > 0 && vm.state != .cleaning,
                    height: 28,
                    action: { vm.cleanSelected() }
                )
                .padding(.horizontal, 16)
            }

            Spacer().frame(height: 4)
        }
    }
}
