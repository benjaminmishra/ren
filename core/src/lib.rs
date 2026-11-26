pub mod domain;
pub mod scanner;
mod targets;
pub mod trash;

use domain::{ScanReport, TrashResult};
use scanner::Scanner;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::panic::{catch_unwind, AssertUnwindSafe};
use trash::TrashManager;

/// Converts a Rust `String` into a heap-allocated C string without panicking.
/// Caller MUST free the returned pointer with `cleaner_free_string`.
fn into_c_string(s: String) -> *mut c_char {
    CString::new(s).unwrap_or_default().into_raw()
}

/// Runs a full filesystem scan and returns a JSON string representing `ScanReport`.
/// Caller MUST call `cleaner_free_string` on the returned pointer.
#[no_mangle]
pub extern "C" fn cleaner_scan_json() -> *mut c_char {
    let json = catch_unwind(|| {
        let scanner = Scanner::new();
        let report: ScanReport = scanner.run_full_scan();
        serde_json::to_string(&report).unwrap_or_else(|_| "{}".into())
    })
    .unwrap_or_else(|_| "{}".into());

    into_c_string(json)
}

/// Scans a single category and returns a JSON array representing `Vec<CleanItem>`.
/// Categories: 0=UserCache, 1=Developer, 2=SystemLog, 3=Trash, 4=AppLeftover,
/// 5=ContainerStorage, 6=MailDownloads, 7=StaleDownloads.
/// Caller MUST call `cleaner_free_string` on the returned pointer.
#[no_mangle]
pub extern "C" fn cleaner_scan_category_json(category_code: i32) -> *mut c_char {
    let json = catch_unwind(|| {
        let scanner = Scanner::new();
        let items = scanner.scan_single_category(category_code);
        serde_json::to_string(&items).unwrap_or_else(|_| "[]".into())
    })
    .unwrap_or_else(|_| "[]".into());

    into_c_string(json)
}

/// Safely moves an array of JSON paths to macOS Trash.
/// Takes a JSON array of path strings, e.g. `["/Users/.../Cache1", "/Users/.../Cache2"]`.
/// Returns a JSON string representing `TrashResult`.
/// Caller MUST call `cleaner_free_string` on the returned pointer.
#[no_mangle]
pub extern "C" fn cleaner_trash_paths_json(paths_json_ptr: *const c_char) -> *mut c_char {
    let json = catch_unwind(AssertUnwindSafe(|| {
        if paths_json_ptr.is_null() {
            let empty_res = TrashResult {
                success: false,
                trashed_paths: vec![],
                failed_paths: vec![],
                error_message: Some("Null pointer passed".into()),
            };
            return serde_json::to_string(&empty_res).unwrap_or_else(|_| "{}".into());
        }

        let c_str = unsafe { CStr::from_ptr(paths_json_ptr) };
        let json_str = match c_str.to_str() {
            Ok(s) => s,
            Err(_) => {
                let res = TrashResult {
                    success: false,
                    trashed_paths: vec![],
                    failed_paths: vec![],
                    error_message: Some("Invalid UTF-8 string".into()),
                };
                return serde_json::to_string(&res).unwrap_or_else(|_| "{}".into());
            }
        };

        let paths: Vec<String> = serde_json::from_str(json_str).unwrap_or_default();
        let result = TrashManager::trash_paths(&paths);
        serde_json::to_string(&result).unwrap_or_else(|_| "{}".into())
    }))
    .unwrap_or_else(|_| "{}".into());

    into_c_string(json)
}

/// Frees a CString allocated by Rust.
#[no_mangle]
pub extern "C" fn cleaner_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            drop(CString::from_raw(ptr));
        }
    }
}

#[cfg(test)]
mod ffi_tests {
    use super::*;

    fn take_string(ptr: *mut c_char) -> String {
        assert!(!ptr.is_null());
        let json = unsafe { CStr::from_ptr(ptr) }.to_str().unwrap().to_owned();
        cleaner_free_string(ptr);
        json
    }

    #[test]
    fn scan_json_has_report_shape() {
        let report: serde_json::Value =
            serde_json::from_str(&take_string(cleaner_scan_json())).unwrap();
        assert!(report["items"].is_array());
        assert!(report["totalBytes"].is_number());
        assert!(report["scanDurationMs"].is_number());
    }

    #[test]
    fn category_scan_returns_json_array() {
        let items: serde_json::Value =
            serde_json::from_str(&take_string(cleaner_scan_category_json(0))).unwrap();
        assert!(items.is_array());
    }

    #[test]
    fn trashing_a_null_pointer_reports_an_error() {
        let result: serde_json::Value =
            serde_json::from_str(&take_string(cleaner_trash_paths_json(std::ptr::null()))).unwrap();
        assert_eq!(result["success"], false);
        assert_eq!(result["errorMessage"], "Null pointer passed");
    }

    #[test]
    fn trashing_an_invalid_json_payload_is_a_no_op() {
        let payload = CString::new("not json").unwrap();
        let result: serde_json::Value =
            serde_json::from_str(&take_string(cleaner_trash_paths_json(payload.as_ptr())))
                .unwrap();
        assert_eq!(result["success"], true);
        assert!(result["trashedPaths"].as_array().unwrap().is_empty());
    }

    #[test]
    fn freeing_a_null_pointer_is_safe() {
        cleaner_free_string(std::ptr::null_mut());
    }
}
