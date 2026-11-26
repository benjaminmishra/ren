import Foundation
import SwiftUI

public enum AppState: Equatable {
    case idle
    case scanning
    case scanned
    case cleaning
    case complete(reclaimed: String)
}

public struct CategorySummary: Identifiable {
    public var id: CleanCategory { category }
    public let category: CleanCategory
    public let totalBytes: UInt64
    public let count: Int
    public let isSelected: Bool

    public var formattedSize: String {
        totalBytes.formattedByteSize
    }
}

public struct ChartSlice: Identifiable {
    public var id: CleanCategory { category }
    public let category: CleanCategory
    public let startAngle: Angle
    public let endAngle: Angle
    public let percentage: Double
}

@MainActor
public final class CleanerViewModel: ObservableObject {
    @Published public var state: AppState = .idle
    @Published public var items: [CleanItem] = []
    @Published public var selectedIds: Set<String> = []
    @Published public var statusMessage: String = "Ready to scan"
    @Published public var scanningCategory: CleanCategory? = nil
    @Published public var completedCategories: Set<CleanCategory> = []
    @Published public var isAdvancedMode: Bool = false
    @Published public var showingAbout: Bool = false

    private var scanTask: Task<Void, Never>?
    private var cleanTask: Task<Void, Never>?

    public var activeCategories: [CleanCategory] {
        isAdvancedMode ? CleanCategory.allCases : CleanCategory.smartCategories
    }

    public init() {}

    deinit {
        scanTask?.cancel()
        cleanTask?.cancel()
    }

    public var categorySummaries: [CategorySummary] {
        activeCategories.compactMap { cat in
            let catItems = items.filter { $0.category == cat }
            guard !catItems.isEmpty else { return nil }
            let total = catItems.map(\.sizeBytes).sum()
            let isSelected = catItems.contains { selectedIds.contains($0.id) }
            return CategorySummary(category: cat, totalBytes: total, count: catItems.count, isSelected: isSelected)
        }
    }

    public var chartSlices: [ChartSlice] {
        let total = Double(totalScannedBytes)
        guard total > 0 else { return [] }

        var currentAngle = Angle(degrees: -90)
        return categorySummaries.map { summary in
            let pct = Double(summary.totalBytes) / total
            let sweep = Angle(degrees: pct * 360)
            let slice = ChartSlice(
                category: summary.category,
                startAngle: currentAngle,
                endAngle: currentAngle + sweep,
                percentage: pct
            )
            currentAngle += sweep
            return slice
        }
    }

    public var selectedBytes: UInt64 {
        items.filter { selectedIds.contains($0.id) }
            .map(\.sizeBytes)
            .sum()
    }

    public var formattedSelectedSize: String {
        selectedBytes.formattedByteSize
    }

    public var totalScannedBytes: UInt64 {
        items.map(\.sizeBytes).sum()
    }

    public var formattedTotalSize: String {
        totalScannedBytes.formattedByteSize
    }

    public func toggleCategory(_ cat: CleanCategory) {
        let catItems = items.filter { $0.category == cat }
        let allSelected = catItems.allSatisfy { selectedIds.contains($0.id) }
        if allSelected {
            for item in catItems { selectedIds.remove(item.id) }
        } else {
            for item in catItems { selectedIds.insert(item.id) }
        }
    }

    public func toggleSelection(for id: String) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    public func startScan() {
        scanTask?.cancel()

        state = .scanning
        items.removeAll()
        selectedIds.removeAll()
        completedCategories.removeAll()
        statusMessage = isAdvancedMode ? "Starting deep advanced scan..." : "Starting smart scan..."

        let startTime = Date()
        let scanList = activeCategories
        let advanced = isAdvancedMode

        scanTask = Task { [weak self] in
            for cat in scanList {
                guard !Task.isCancelled, let self = self else { return }
                self.scanningCategory = cat
                self.statusMessage = "Scanning \(cat.title)..."

                do {
                    let catItems = try await CleanerBridge.shared.scanCategory(cat)
                    guard !Task.isCancelled else { return }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        self.items.append(contentsOf: catItems)
                        for item in catItems where item.isDefaultSelected {
                            self.selectedIds.insert(item.id)
                        }
                        _ = self.completedCategories.insert(cat)
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    print("Error scanning \(cat): \(error)")
                    withAnimation {
                        _ = self.completedCategories.insert(cat)
                    }
                }

                // Smooth rhythm so the user can see each category discovery live
                try? await Task.sleep(nanoseconds: 70_000_000)
            }

            guard !Task.isCancelled, let self = self else { return }
            let elapsedMs = UInt64(Date().timeIntervalSince(startTime) * 1000)
            self.scanningCategory = nil
            self.state = .scanned
            self.statusMessage = "\(advanced ? "Advanced" : "Smart") scan: Found \(self.formattedTotalSize) in \(elapsedMs)ms"
            self.scanTask = nil
        }
    }

    public func cleanSelected() {
        guard state != .cleaning else { return }
        let targets = items.filter { selectedIds.contains($0.id) }
        guard !targets.isEmpty else { return }

        cleanTask?.cancel()
        state = .cleaning
        statusMessage = "Moving to Trash..."
        let paths = targets.map(\.path)
        let freedFormatted = formattedSelectedSize

        cleanTask = Task { [weak self] in
            do {
                let result = try await CleanerBridge.shared.trash(paths: paths)
                guard !Task.isCancelled, let self = self else { return }
                let trashedSet = Set(result.trashedPaths)

                self.items.removeAll { trashedSet.contains($0.path) }
                self.selectedIds.removeAll()
                self.state = .complete(reclaimed: freedFormatted)
                self.statusMessage = "Safely reclaimed \(freedFormatted)"
                self.cleanTask = nil
            } catch {
                guard !Task.isCancelled, let self = self else { return }
                self.state = .scanned
                self.statusMessage = "Clean failed: \(error.localizedDescription)"
                self.cleanTask = nil
            }
        }
    }
}

internal extension Sequence where Element == UInt64 {
    func sum() -> UInt64 {
        reduce(0, +)
    }
}
