use crate::domain::TrashResult;
use std::path::Path;

pub struct TrashManager;

impl TrashManager {
    /// Safely moves the given file/folder paths to ~/.Trash using native macOS APIs.
    pub fn trash_paths(paths: &[String]) -> TrashResult {
        let mut trashed = Vec::new();
        let mut failed = Vec::new();
        let mut last_error = None;

        for path_str in paths {
            let path = Path::new(path_str);
            if !path.exists() {
                continue;
            }

            // trash::delete uses NSFileManager trashItemAtURL on macOS
            match trash::delete(path) {
                Ok(_) => trashed.push(path_str.clone()),
                Err(err) => {
                    last_error = Some(err.to_string());
                    failed.push(path_str.clone());
                }
            }
        }

        TrashResult {
            success: failed.is_empty(),
            trashed_paths: trashed,
            failed_paths: failed,
            error_message: last_error,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn missing_paths_are_skipped() {
        let missing = "/definitely/not/here/cleaner-test".to_string();
        let result = TrashManager::trash_paths(&[missing]);
        assert!(result.success);
        assert!(result.trashed_paths.is_empty());
        assert!(result.failed_paths.is_empty());
        assert!(result.error_message.is_none());
    }

    #[test]
    fn empty_input_succeeds() {
        let result = TrashManager::trash_paths(&[]);
        assert!(result.success);
        assert!(result.trashed_paths.is_empty());
        assert!(result.failed_paths.is_empty());
    }
}
