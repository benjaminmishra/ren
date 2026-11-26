import Foundation

// Direct zero-overhead C-ABI bindings to the Rust engine
@_silgen_name("cleaner_scan_json")
private func cleaner_scan_json() -> UnsafeMutablePointer<CChar>?

@_silgen_name("cleaner_scan_category_json")
private func cleaner_scan_category_json(_ categoryCode: Int32) -> UnsafeMutablePointer<CChar>?

@_silgen_name("cleaner_trash_paths_json")
private func cleaner_trash_paths_json(_ pathsJson: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?

@_silgen_name("cleaner_free_string")
private func cleaner_free_string(_ ptr: UnsafeMutablePointer<CChar>?)

public enum BridgeError: LocalizedError {
    case nullPointer
    case serializationError(String)

    public var errorDescription: String? {
        switch self {
        case .nullPointer: return "Rust engine returned null"
        case .serializationError(let err): return "Serialization error: \(err)"
        }
    }
}

public final class CleanerBridge {
    public static let shared = CleanerBridge()

    private init() {}

    /// Runs a full parallel Rust file scan asynchronously on a background thread.
    public func scan() async throws -> ScanReport {
        try await invokeJSON { cleaner_scan_json() }
    }

    /// Scans a single category asynchronously on a background thread for gradual UI streaming.
    public func scanCategory(_ category: CleanCategory) async throws -> [CleanItem] {
        let code = category.ffiCode
        return try await invokeJSON { cleaner_scan_category_json(code) }
    }

    /// Safely moves paths to macOS Trash via Rust/NSFileManager.
    public func trash(paths: [String]) async throws -> TrashResult {
        let data = try JSONEncoder().encode(paths)
        guard let payload = String(data: data, encoding: .utf8) else {
            throw BridgeError.serializationError("Failed to encode paths")
        }
        return try await invokeJSON {
            payload.withCString { cleaner_trash_paths_json($0) }
        }
    }

    /// Single audited FFI boundary: executes a C-ABI call on a background thread
    /// inside an autorelease pool, frees the Rust-allocated CString via `defer`,
    /// and decodes the returned JSON payload.
    private func invokeJSON<T: Decodable>(
        _ call: @escaping () -> UnsafeMutablePointer<CChar>?
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                autoreleasepool {
                    guard let ptr = call() else {
                        continuation.resume(throwing: BridgeError.nullPointer)
                        return
                    }
                    defer { cleaner_free_string(ptr) }

                    guard let data = String(cString: ptr).data(using: .utf8) else {
                        continuation.resume(throwing: BridgeError.serializationError("Invalid UTF-8"))
                        return
                    }

                    do {
                        let decoded = try JSONDecoder().decode(T.self, from: data)
                        continuation.resume(returning: decoded)
                    } catch {
                        continuation.resume(throwing: BridgeError.serializationError(error.localizedDescription))
                    }
                }
            }
        }
    }
}
