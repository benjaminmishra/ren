import SwiftUI
import AppKit

public struct DashboardView: View {
    @ObservedObject var vm: CleanerViewModel
    @State private var showingDetails = false
    @State private var isWidgetMode = false

    private static let widgetSize = CGSize(width: 220, height: 240)
    private static let dashboardSize = CGSize(width: 460, height: 370)

    public init(vm: CleanerViewModel) {
        self.vm = vm
    }

    public var body: some View {
        let size = isWidgetMode ? Self.widgetSize : Self.dashboardSize

        ZStack {
            VisualEffectBackground()
                .ignoresSafeArea()

            Theme.slateBackground.opacity(0.72)
                .ignoresSafeArea()

            WindowAccessor(initialSize: Self.dashboardSize)
                .frame(width: 0, height: 0)

            if isWidgetMode {
                MiniWidgetView(vm: vm, onExpand: toggleWidgetMode)
            } else {
                fullDashboardView
            }
        }
        .frame(
            minWidth: size.width - 20,
            idealWidth: size.width,
            minHeight: size.height - 20,
            idealHeight: size.height
        )
        .sheet(isPresented: $showingDetails) {
            FileDetailsSheet(vm: vm, isPresented: $showingDetails)
        }
    }

    // MARK: - Full Compact Dashboard View
    private var fullDashboardView: some View {
        VStack(spacing: 0) {
            headerBar
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 6)

            // Consistent two-column layout so the donut never shifts when results arrive
            HStack(alignment: .center, spacing: 18) {
                leftDonutColumn
                    .frame(width: 160)

                rightContentColumn
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            footerBar
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                RenLogoMark(size: 16)

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("Ren")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    Text("v\(AppInfo.version)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Theme.textMuted.opacity(0.6))
                }
            }

            Spacer()

            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    modePill(
                        title: "Smart",
                        icon: nil,
                        activeColor: Theme.cyan.opacity(0.25),
                        isActive: !vm.isAdvancedMode
                    ) {
                        setAdvancedMode(false)
                    }

                    modePill(
                        title: "Advanced",
                        icon: "bolt.badge.a",
                        activeColor: Theme.purple.opacity(0.35),
                        isActive: vm.isAdvancedMode
                    ) {
                        setAdvancedMode(true)
                    }
                }
                .padding(2)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())

                if case .scanned = vm.state {
                    Button(action: { vm.startScan() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Theme.textMuted)
                            .padding(5)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Rescan storage")
                }

                Button(action: toggleWidgetMode) {
                    HStack(spacing: 4) {
                        Image(systemName: "pip.enter")
                            .font(.system(size: 11, weight: .medium))
                        Text("Widget")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(Theme.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Switch to floating desktop widget")
            }
        }
    }

    private func modePill(
        title: String,
        icon: String?,
        activeColor: Color,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 8))
                }
                Text(title)
            }
            .font(.system(size: 10, weight: isActive ? .bold : .regular))
            .foregroundColor(isActive ? .white : Theme.textMuted.opacity(0.6))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(isActive ? activeColor : Color.clear)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func setAdvancedMode(_ enabled: Bool) {
        guard vm.state != .scanning else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            vm.isAdvancedMode = enabled
        }
    }

    private func toggleWidgetMode() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isWidgetMode.toggle()
        }

        if let window = NSApp.keyWindow ?? NSApp.windows.first {
            window.setContentSize(isWidgetMode ? Self.widgetSize : Self.dashboardSize)
            window.level = isWidgetMode ? .floating : .normal
        }
    }

    // MARK: - Left Anchored Column (Donut + Bottom Action Button)
    private var leftDonutColumn: some View {
        VStack(spacing: 12) {
            ZStack {
                switch vm.state {
                case .idle:
                    statusRing(topColor: Color.white.opacity(0.14), bottomColor: Color.white.opacity(0.02))
                        .overlay(
                            Circle()
                                .stroke(Theme.cyan.opacity(0.35), lineWidth: 1.5)
                                .shadow(color: Theme.cyan.opacity(0.35), radius: 5)
                        )

                    VStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 26))
                            .foregroundColor(Theme.cyan)
                            .shadow(color: Theme.cyan.opacity(0.6), radius: 8)
                        Text("Ready")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                    }

                case .scanning:
                    if vm.chartSlices.isEmpty {
                        statusRing(topColor: Theme.cyan.opacity(0.3), bottomColor: Color.white.opacity(0.05))
                        VStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.95)
                                .colorInvert()
                            Text("Scanning")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(Theme.cyan)
                        }
                    } else {
                        donutPodView(sublabel: "Scanning...")
                    }

                case .scanned, .cleaning:
                    donutPodView(sublabel: vm.selectedBytes == vm.totalScannedBytes ? "Cleanable" : "Selected")

                case .complete(let reclaimed):
                    statusRing(topColor: Theme.lime.opacity(0.4), bottomColor: Theme.lime.opacity(0.06))
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Theme.lime)
                            .shadow(color: Theme.lime.opacity(0.7), radius: 8)
                        Text(reclaimed)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
            }
            .frame(width: 135, height: 135)

            primaryActionButton
                .frame(width: 155)
        }
    }

    @ViewBuilder
    private var primaryActionButton: some View {
        switch vm.state {
        case .idle:
            LiquidGlassButton(
                title: "Start Scan",
                icon: "sparkles",
                gradientColors: Theme.scanGradient,
                isEnabled: true,
                height: 32,
                action: { vm.startScan() }
            )

        case .scanning:
            LiquidGlassButton(
                title: "Scanning...",
                icon: "rays",
                gradientColors: Theme.disabledGradient,
                isEnabled: false,
                height: 32,
                action: {}
            )

        case .scanned, .cleaning:
            LiquidGlassButton(
                title: "Move to Trash",
                icon: "trash.fill",
                gradientColors: Theme.trashGradient,
                isEnabled: vm.selectedBytes > 0 && vm.state != .cleaning,
                height: 32,
                action: { vm.cleanSelected() }
            )

        case .complete:
            LiquidGlassButton(
                title: "Scan Again",
                icon: "arrow.clockwise",
                gradientColors: Theme.scanGradient,
                isEnabled: true,
                height: 32,
                action: { vm.startScan() }
            )
        }
    }

    private func statusRing(topColor: Color, bottomColor: Color) -> some View {
        Circle()
            .strokeBorder(
                LinearGradient(colors: [topColor, bottomColor], startPoint: .top, endPoint: .bottom),
                lineWidth: 15
            )
            .frame(width: 135, height: 135)
    }

    private func donutPodView(sublabel: String) -> some View {
        ZStack {
            DonutChartView(slices: vm.chartSlices, strokeWidth: 15)
                .frame(width: 135, height: 135)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.12), Color.white.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 82, height: 82)

                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), Color.white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 82, height: 82)

                VStack(spacing: 2) {
                    Text(vm.formattedSelectedSize)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(sublabel)
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.cyan)
                        .textCase(.uppercase)
                }
            }
            .shadow(color: Color.black.opacity(0.25), radius: 6, y: 2)
        }
    }

    // MARK: - Right Content Column (Categories / Status)
    private var rightContentColumn: some View {
        Group {
            switch vm.state {
            case .idle:
                idleRightColumn
            case .scanning:
                scanningRightColumn
            case .scanned, .cleaning:
                scannedRightColumn
            case .complete(let reclaimed):
                completeRightColumn(reclaimed: reclaimed)
            }
        }
    }

    private var idleRightColumn: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(vm.isAdvancedMode ? "ADVANCED TARGETS (8)" : "DISCOVERY TARGETS (4)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textMuted.opacity(0.75))
                Spacer()
                Text(vm.isAdvancedMode ? "Deep analysis" : "Fast & safe")
                    .font(.system(size: 8))
                    .foregroundColor(Theme.textMuted.opacity(0.5))
            }
            .padding(.bottom, 1)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(vm.activeCategories, id: \.self) { cat in
                        idleCategoryPreview(cat)
                    }
                }
            }
            .frame(maxHeight: 225)
        }
    }

    private var scanningRightColumn: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(vm.isAdvancedMode ? "DEEP SYSTEM SCAN" : "SCANNING SYSTEM")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textMuted.opacity(0.75))
                Spacer()
                ProgressView()
                    .scaleEffect(0.6)
                    .colorInvert()
            }
            .padding(.bottom, 1)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(vm.activeCategories, id: \.self) { cat in
                        ScanningCategoryRow(
                            cat: cat,
                            items: vm.items.filter { $0.category == cat },
                            isCompleted: vm.completedCategories.contains(cat),
                            isCurrent: vm.scanningCategory == cat
                        )
                    }
                }
            }
            .frame(maxHeight: 225)
        }
    }

    private var scannedRightColumn: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(vm.isAdvancedMode ? "ADVANCED CATEGORIES" : "CATEGORIES")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textMuted.opacity(0.75))
                Spacer()
                Text("Toggle to include")
                    .font(.system(size: 9))
                    .foregroundColor(Theme.textMuted.opacity(0.5))
            }
            .padding(.bottom, 1)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(vm.categorySummaries) { summary in
                        LiquidGlassCategoryCard(
                            summary: summary,
                            isSelected: summary.isSelected,
                            onToggle: { vm.toggleCategory(summary.category) }
                        )
                    }
                }
            }
            .frame(maxHeight: 225)
        }
    }

    private func completeRightColumn(reclaimed: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CLEANUP COMPLETED")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textMuted.opacity(0.75))

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(Theme.lime)
                        .font(.system(size: 16))
                    Text("Successfully Reclaimed")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text("\(reclaimed) moved to macOS Trash safely.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textMuted)

                Text("You can restore any file from the Trash anytime.")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textMuted.opacity(0.7))
            }
            .padding(12)
            .background(LiquidGlassBackground(cornerRadius: 10))
        }
    }

    private func idleCategoryPreview(_ cat: CleanCategory) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(cat.color.opacity(0.6))
                .frame(width: 8, height: 8)

            Image(systemName: cat.iconName)
                .font(.system(size: 11))
                .foregroundColor(cat.color)
                .frame(width: 14)

            Text(cat.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.textSecondary)

            Spacer()

            Text("Ready")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Theme.textMuted.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(LiquidGlassBackground(cornerRadius: 8, intensity: 0.7))
    }

    // MARK: - Footer
    private var footerBar: some View {
        HStack {
            Text(vm.statusMessage)
                .font(.system(size: 11))
                .foregroundColor(Theme.textMuted.opacity(0.7))

            Spacer()

            if !vm.items.isEmpty {
                Button(action: { showingDetails = true }) {
                    HStack(spacing: 4) {
                        Text("Inspect \(vm.items.count) Files")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.cyan)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
