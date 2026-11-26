import Foundation
import SwiftUI

public enum CleanCategory: String, Codable, CaseIterable {
    case userCache
    case developer
    case systemLog
    case trash
    case appLeftover
    case containerStorage
    case mailDownloads
    case staleDownloads

    public static var smartCategories: [CleanCategory] {
        [.userCache, .systemLog, .trash, .appLeftover]
    }

    public static var advancedCategories: [CleanCategory] {
        [.developer, .containerStorage, .mailDownloads, .staleDownloads]
    }

    public var isAdvanced: Bool {
        Self.advancedCategories.contains(self)
    }

    /// Integer code expected by `cleaner_scan_category_json` in the Rust core.
    public var ffiCode: Int32 {
        switch self {
        case .userCache: return 0
        case .developer: return 1
        case .systemLog: return 2
        case .trash: return 3
        case .appLeftover: return 4
        case .containerStorage: return 5
        case .mailDownloads: return 6
        case .staleDownloads: return 7
        }
    }

    public var title: String {
        switch self {
        case .userCache: return "App Caches"
        case .developer: return "Developer Tools"
        case .systemLog: return "System Logs"
        case .trash: return "Trash Bin"
        case .appLeftover: return "App Leftovers"
        case .containerStorage: return "Containers & VMs"
        case .mailDownloads: return "Mail & Backups"
        case .staleDownloads: return "Stale Downloads"
        }
    }

    /// Vibrant One Dark Pro / Monokai palette
    public var color: Color {
        switch self {
        case .userCache:        return Theme.cyan
        case .developer:        return Theme.purple
        case .systemLog:        return Theme.amber
        case .trash:            return Theme.neonPink
        case .appLeftover:      return Theme.lime
        case .containerStorage: return Theme.skyBlue
        case .mailDownloads:    return Theme.mint
        case .staleDownloads:   return Theme.orange
        }
    }

    public var iconName: String {
        switch self {
        case .userCache: return "bolt.fill"
        case .developer: return "terminal.fill"
        case .systemLog: return "doc.text.fill"
        case .trash: return "trash.fill"
        case .appLeftover: return "shippingbox.fill"
        case .containerStorage: return "cube.fill"
        case .mailDownloads: return "envelope.fill"
        case .staleDownloads: return "arrow.down.circle.fill"
        }
    }
}

public struct CleanItem: Identifiable, Codable, Equatable {
    public let id: String
    public let name: String
    public let path: String
    public let sizeBytes: UInt64
    public let category: CleanCategory
    public let description: String
    public let isDefaultSelected: Bool

    public var formattedSize: String {
        sizeBytes.formattedByteSize
    }
}

public struct ScanReport: Codable {
    public let items: [CleanItem]
    public let totalBytes: UInt64
    public let scanDurationMs: UInt64

    public var formattedTotal: String {
        totalBytes.formattedByteSize
    }
}

public struct TrashResult: Codable {
    public let success: Bool
    public let trashedPaths: [String]
    public let failedPaths: [String]
    public let errorMessage: String?
}

public extension UInt64 {
    var formattedByteSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .file)
    }
}
