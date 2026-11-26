import XCTest
@testable import RenKit

final class DomainTests: XCTestCase {
    func testSmartAndAdvancedCategoriesCoverEveryCase() {
        let smart = Set(CleanCategory.smartCategories)
        let advanced = Set(CleanCategory.advancedCategories)
        XCTAssertTrue(smart.isDisjoint(with: advanced))
        XCTAssertEqual(smart.union(advanced), Set(CleanCategory.allCases))
    }

    func testIsAdvancedMatchesAdvancedCategories() {
        for category in CleanCategory.allCases {
            XCTAssertEqual(
                category.isAdvanced,
                CleanCategory.advancedCategories.contains(category),
                "\(category)"
            )
        }
    }

    func testEveryCategoryHasTitleIconAndUniqueFFICode() {
        let codes = CleanCategory.allCases.map(\.ffiCode)
        XCTAssertEqual(Set(codes).count, CleanCategory.allCases.count)
        for category in CleanCategory.allCases {
            XCTAssertFalse(category.title.isEmpty, "\(category)")
            XCTAssertFalse(category.iconName.isEmpty, "\(category)")
        }
    }

    func testDecodesTheRustCoreReportShape() throws {
        let json = """
        {
          "items": [{
            "id": "cache_x", "name": "Cache: x", "path": "/tmp/x",
            "sizeBytes": 42, "category": "userCache",
            "description": "d", "isDefaultSelected": true
          }],
          "totalBytes": 42,
          "scanDurationMs": 7
        }
        """
        let report = try JSONDecoder().decode(ScanReport.self, from: Data(json.utf8))
        XCTAssertEqual(report.items.count, 1)
        XCTAssertEqual(report.totalBytes, 42)
        XCTAssertEqual(report.items[0].category, .userCache)
        XCTAssertTrue(report.items[0].isDefaultSelected)
    }
}

@MainActor
final class CleanerViewModelTests: XCTestCase {
    private func item(_ id: String, _ bytes: UInt64, _ category: CleanCategory, selected: Bool = false) -> CleanItem {
        CleanItem(
            id: id, name: id, path: "/tmp/\(id)", sizeBytes: bytes,
            category: category, description: "", isDefaultSelected: selected
        )
    }

    func testSelectedBytesSumsOnlySelectedItems() {
        let vm = CleanerViewModel()
        vm.items = [
            item("a", 100, .userCache, selected: true),
            item("b", 250, .developer),
        ]
        vm.selectedIds = ["a"]
        XCTAssertEqual(vm.selectedBytes, 100)
        XCTAssertEqual(vm.totalScannedBytes, 350)
    }

    func testToggleCategorySelectsThenDeselects() {
        let vm = CleanerViewModel()
        vm.items = [item("a", 1, .trash), item("b", 1, .trash), item("c", 1, .userCache)]

        vm.toggleCategory(.trash)
        XCTAssertEqual(vm.selectedIds, ["a", "b"])

        vm.toggleCategory(.trash)
        XCTAssertTrue(vm.selectedIds.isEmpty)
    }

    func testToggleSelectionFlipsSingleItem() {
        let vm = CleanerViewModel()
        vm.toggleSelection(for: "a")
        XCTAssertEqual(vm.selectedIds, ["a"])
        vm.toggleSelection(for: "a")
        XCTAssertTrue(vm.selectedIds.isEmpty)
    }

    func testChartSlicesSpanFullCircleInAdvancedMode() {
        let vm = CleanerViewModel()
        vm.isAdvancedMode = true
        vm.items = [
            item("a", 100, .userCache),
            item("b", 300, .developer),
        ]
        let slices = vm.chartSlices
        XCTAssertEqual(slices.count, 2)
        XCTAssertEqual(slices[0].percentage, 0.25, accuracy: 0.0001)
        XCTAssertEqual(slices[1].percentage, 0.75, accuracy: 0.0001)
    }

    func testViewModelDeallocatesCleanlyDuringScan() async {
        weak var weakVM: CleanerViewModel?
        do {
            let vm = CleanerViewModel()
            weakVM = vm
            vm.startScan()
        }
        // Allow cancelled task suspension points to settle
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertNil(weakVM, "CleanerViewModel should not be retained by in-flight scan tasks")
    }
}
