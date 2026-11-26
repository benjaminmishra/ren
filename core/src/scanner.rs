use crate::domain::{CleanCategory, CleanItem, ScanReport};
use crate::targets::{
    TargetSpec, CONTAINER_TARGETS, DEVELOPER_TARGETS, LOG_TARGETS, MAIL_TARGETS, MB, TRASH_TARGETS,
};
use jwalk::WalkDir;
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant, SystemTime};

pub struct Scanner {
    home_dir: PathBuf,
}

impl Scanner {
    pub fn new() -> Self {
        Self::with_home(dirs::home_dir().unwrap_or_else(|| PathBuf::from("/")))
    }

    /// Builds a scanner rooted at `home_dir` instead of the real home
    /// directory. Used by tests to scan temporary fixtures.
    pub fn with_home(home_dir: impl Into<PathBuf>) -> Self {
        Self {
            home_dir: home_dir.into(),
        }
    }

    /// Fast parallel scan of all eligible cleanup targets.
    pub fn run_full_scan(&self) -> ScanReport {
        let start = Instant::now();
        let mut items = Vec::new();

        for code in 0..=7 {
            if let Some(category) = CleanCategory::from_code(code) {
                self.scan_category(category, &mut items);
            }
        }

        items.sort_by(|a, b| b.size_bytes.cmp(&a.size_bytes));
        let total_bytes = items.iter().map(|i| i.size_bytes).sum();

        ScanReport {
            items,
            total_bytes,
            scan_duration_ms: start.elapsed().as_millis() as u64,
        }
    }

    /// Fast scan of a single category for progressive/gradual UI streaming.
    pub fn scan_single_category(&self, category_code: i32) -> Vec<CleanItem> {
        let mut items = Vec::new();
        if let Some(category) = CleanCategory::from_code(category_code) {
            self.scan_category(category, &mut items);
        }
        items.sort_by(|a, b| b.size_bytes.cmp(&a.size_bytes));
        items
    }

    fn scan_category(&self, category: CleanCategory, items: &mut Vec<CleanItem>) {
        match category {
            CleanCategory::UserCache => self.scan_user_caches(items),
            CleanCategory::Developer => self.scan_targets(DEVELOPER_TARGETS, items),
            CleanCategory::SystemLog => self.scan_targets(LOG_TARGETS, items),
            CleanCategory::Trash => self.scan_targets(TRASH_TARGETS, items),
            CleanCategory::AppLeftover => self.scan_app_leftovers(items),
            CleanCategory::ContainerStorage => self.scan_targets(CONTAINER_TARGETS, items),
            CleanCategory::MailDownloads => self.scan_targets(MAIL_TARGETS, items),
            CleanCategory::StaleDownloads => self.scan_stale_downloads(items),
        }
    }

    fn scan_targets(&self, specs: &[TargetSpec], items: &mut Vec<CleanItem>) {
        for spec in specs {
            let path = self.home_dir.join(spec.rel_path);
            if !path.exists() {
                continue;
            }
            let size = calculate_dir_size(&path);
            if size > spec.min_bytes {
                items.push(CleanItem {
                    id: spec.id.into(),
                    name: spec.name.into(),
                    path: path.to_string_lossy().into_owned(),
                    size_bytes: size,
                    category: spec.category,
                    description: spec.description.into(),
                    is_default_selected: spec.category.default_selected(),
                });
            }
        }
    }

    fn scan_user_caches(&self, items: &mut Vec<CleanItem>) {
        let caches_dir = self.home_dir.join("Library/Caches");
        let Ok(entries) = std::fs::read_dir(&caches_dir) else {
            return;
        };

        for entry in entries.flatten() {
            // Use file_type() (lstat) so symlinks are never followed into arbitrary dirs
            if !entry.file_type().map(|ft| ft.is_dir()).unwrap_or(false) {
                continue;
            }
            let path = entry.path();
            let size = calculate_dir_size(&path);
            if size > 10 * MB {
                let name = entry.file_name().to_string_lossy().into_owned();
                items.push(CleanItem {
                    id: format!("cache_{name}"),
                    name: format!("Cache: {name}"),
                    path: path.to_string_lossy().into_owned(),
                    size_bytes: size,
                    category: CleanCategory::UserCache,
                    description: "Temporary application cache that regenerates on demand.".into(),
                    is_default_selected: CleanCategory::UserCache.default_selected(),
                });
            }
        }
    }

    fn scan_stale_downloads(&self, items: &mut Vec<CleanItem>) {
        let downloads_dir = self.home_dir.join("Downloads");
        let Ok(entries) = std::fs::read_dir(&downloads_dir) else {
            return;
        };

        const INSTALLER_EXTS: &[&str] = &["dmg", "pkg", "iso", "zip", "gz", "tgz", "bz2"];
        let thirty_days_ago = SystemTime::now()
            .checked_sub(Duration::from_secs(30 * 86400))
            .unwrap_or(SystemTime::UNIX_EPOCH);

        for entry in entries.flatten() {
            let Ok(metadata) = entry.metadata() else {
                continue;
            };
            let path = entry.path();
            let size = if metadata.is_dir() {
                calculate_dir_size(&path)
            } else {
                metadata.len()
            };

            let ext = path
                .extension()
                .and_then(|e| e.to_str())
                .unwrap_or("")
                .to_lowercase();
            let is_installer = INSTALLER_EXTS.contains(&ext.as_str());
            let is_old = metadata
                .modified()
                .map(|m| m < thirty_days_ago)
                .unwrap_or(false);

            if (is_installer && size > 30 * MB) || (is_old && size > 50 * MB) {
                let name = entry.file_name().to_string_lossy().into_owned();
                items.push(CleanItem {
                    id: format!("download_{name}"),
                    name: format!("Installer / Archive: {name}"),
                    path: path.to_string_lossy().into_owned(),
                    size_bytes: size,
                    category: CleanCategory::StaleDownloads,
                    description: if is_installer {
                        "Disk image or installer archive kept in Downloads.".into()
                    } else {
                        "Large file in Downloads not modified in over 30 days.".into()
                    },
                    is_default_selected: CleanCategory::StaleDownloads.default_selected(),
                });
            }
        }
    }

    fn scan_app_leftovers(&self, items: &mut Vec<CleanItem>) {
        let app_support = self.home_dir.join("Library/Application Support");
        let Ok(entries) = std::fs::read_dir(&app_support) else {
            return;
        };

        let installed_apps = self.installed_app_names();
        const SYSTEM_FOLDERS: &[&str] = &[
            "apple",
            "crashreporter",
            "dock",
            "syncservices",
            "addressbook",
            "icdd",
            "knowledge",
            "clouddocs",
            "callhistorydb",
            "tcc",
            "caches",
        ];

        for entry in entries.flatten() {
            // Use file_type() (lstat) so symlinks are never followed into arbitrary dirs
            if !entry.file_type().map(|ft| ft.is_dir()).unwrap_or(false) {
                continue;
            }
            let name = entry.file_name().to_string_lossy().into_owned();
            let name_lower = name.to_lowercase();

            if SYSTEM_FOLDERS.iter().any(|&s| name_lower.contains(s))
                || installed_apps
                    .iter()
                    .any(|app| name_lower.contains(app) || app.contains(&name_lower))
            {
                continue;
            }

            let path = entry.path();
            let size = calculate_dir_size(&path);
            if size > 20 * MB {
                items.push(CleanItem {
                    id: format!("leftover_{name}"),
                    name: format!("Leftover: {name}"),
                    path: path.to_string_lossy().into_owned(),
                    size_bytes: size,
                    category: CleanCategory::AppLeftover,
                    description: format!(
                        "Application Support data for '{name}', which doesn't appear in Applications."
                    ),
                    is_default_selected: CleanCategory::AppLeftover.default_selected(),
                });
            }
        }
    }

    fn installed_app_names(&self) -> std::collections::HashSet<String> {
        let mut names = std::collections::HashSet::new();
        let user_apps = self.home_dir.join("Applications");
        for root in [Path::new("/Applications"), user_apps.as_path()] {
            if let Ok(entries) = std::fs::read_dir(root) {
                for entry in entries.flatten() {
                    let name = entry.file_name().to_string_lossy().to_lowercase();
                    if let Some(base) = name.strip_suffix(".app") {
                        names.insert(base.to_owned());
                    }
                }
            }
        }
        names
    }
}

/// Calculates directory size efficiently using parallel traversal.
pub fn calculate_dir_size(dir: &Path) -> u64 {
    WalkDir::new(dir)
        .into_iter()
        .filter_map(|e| e.ok())
        .filter_map(|e| e.metadata().ok())
        .filter(|m| m.is_file())
        .map(|m| m.len())
        .sum()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    /// Creates an isolated fake home directory for one test.
    fn fake_home(name: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!(
            "cleaner-test-{}-{}",
            name,
            std::process::id()
        ));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    fn write_file(path: &Path, bytes: usize) {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).unwrap();
        }
        fs::write(path, vec![0u8; bytes]).unwrap();
    }

    #[test]
    fn calculates_directory_size_recursively() {
        let home = fake_home("size");
        write_file(&home.join("a/file1"), 100);
        write_file(&home.join("a/nested/file2"), 50);
        assert_eq!(calculate_dir_size(&home.join("a")), 150);
        assert_eq!(calculate_dir_size(&home.join("missing")), 0);
        let _ = fs::remove_dir_all(&home);
    }

    #[test]
    fn scan_ignores_small_caches_and_reports_large_ones() {
        let home = fake_home("caches");
        write_file(&home.join("Library/Caches/small/item"), 1024);
        write_file(
            &home.join("Library/Caches/large/item"),
            11 * 1024 * 1024,
        );

        let items = Scanner::with_home(&home).scan_single_category(0);
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].id, "cache_large");
        assert_eq!(items[0].category, CleanCategory::UserCache);
        assert!(items[0].size_bytes > 10 * 1024 * 1024);
        let _ = fs::remove_dir_all(&home);
    }

    #[test]
    fn scan_trash_reports_non_empty_trash_only() {
        let home = fake_home("trash");
        let empty = Scanner::with_home(&home).scan_single_category(3);
        assert!(empty.is_empty(), "missing trash dir yields nothing");

        write_file(&home.join(".Trash/old.txt"), 10);
        let items = Scanner::with_home(&home).scan_single_category(3);
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].id, "user_trash");
        let _ = fs::remove_dir_all(&home);
    }

    #[test]
    fn scan_results_are_sorted_by_size() {
        let home = fake_home("sorted");
        write_file(&home.join("Library/Caches/small/item"), 11 * 1024 * 1024);
        write_file(&home.join("Library/Caches/big/item"), 20 * 1024 * 1024);

        let items = Scanner::with_home(&home).scan_single_category(0);
        assert_eq!(items.len(), 2);
        assert!(items[0].size_bytes >= items[1].size_bytes);
        assert_eq!(items[0].id, "cache_big");
        let _ = fs::remove_dir_all(&home);
    }

    #[test]
    fn unknown_category_code_is_empty() {
        let home = fake_home("unknown");
        assert!(Scanner::with_home(&home).scan_single_category(99).is_empty());
        let _ = fs::remove_dir_all(&home);
    }

    fn set_age_days(path: &Path, days: u64) {
        let old = SystemTime::now() - Duration::from_secs(days * 86400);
        let file = fs::File::options().write(true).open(path).unwrap();
        file.set_modified(old).unwrap();
    }

    #[test]
    fn logs_are_reported_above_one_megabyte() {
        let home = fake_home("logs");
        write_file(&home.join("Library/Logs/tiny.log"), 512);
        assert!(Scanner::with_home(&home).scan_single_category(2).is_empty());

        write_file(&home.join("Library/Logs/big.log"), 2 * 1024 * 1024);
        let items = Scanner::with_home(&home).scan_single_category(2);
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].id, "system_logs");
        let _ = fs::remove_dir_all(&home);
    }

    #[test]
    fn stale_downloads_requires_large_installers_or_old_files() {
        let home = fake_home("downloads");
        let downloads = home.join("Downloads");
        // A dmg over 30 MB is an installer and is reported.
        write_file(&downloads.join("tool.dmg"), 31 * 1024 * 1024);
        // A small installer is not.
        write_file(&downloads.join("small.dmg"), 1024);
        // A big recent non-installer is not reported.
        write_file(&downloads.join("recent.bin"), 60 * 1024 * 1024);
        // A big old non-installer is reported.
        let old = downloads.join("old.bin");
        write_file(&old, 60 * 1024 * 1024);
        set_age_days(&old, 40);

        let items = Scanner::with_home(&home).scan_single_category(7);
        let ids: Vec<&str> = items.iter().map(|i| i.id.as_str()).collect();
        assert!(ids.contains(&"download_tool.dmg"), "{ids:?}");
        assert!(ids.contains(&"download_old.bin"), "{ids:?}");
        assert!(!ids.contains(&"download_small.dmg"), "{ids:?}");
        assert!(!ids.contains(&"download_recent.bin"), "{ids:?}");
        let _ = fs::remove_dir_all(&home);
    }

    #[test]
    fn mail_and_backups_are_separate_items() {
        let home = fake_home("mail");
        write_file(
            &home.join("Library/Containers/com.apple.mail/Data/Library/Mail Downloads/a.zip"),
            6 * 1024 * 1024,
        );
        write_file(
            &home.join("Library/Application Support/MobileSync/Backup/b/file"),
            51 * 1024 * 1024,
        );

        let items = Scanner::with_home(&home).scan_single_category(6);
        let ids: Vec<&str> = items.iter().map(|i| i.id.as_str()).collect();
        assert!(ids.contains(&"apple_mail_downloads"), "{ids:?}");
        assert!(ids.contains(&"ios_device_backups"), "{ids:?}");
        assert!(items.iter().all(|i| i.category == CleanCategory::MailDownloads));
        let _ = fs::remove_dir_all(&home);
    }

    #[test]
    fn container_storage_reports_large_vms() {
        let home = fake_home("containers");
        write_file(&home.join(".colima/disk/image"), 101 * 1024 * 1024);
        write_file(&home.join(".docker/buildx/cache/blob"), 10 * 1024 * 1024);

        let items = Scanner::with_home(&home).scan_single_category(5);
        let ids: Vec<&str> = items.iter().map(|i| i.id.as_str()).collect();
        assert_eq!(ids, vec!["colima_vm_storage"]);
        let _ = fs::remove_dir_all(&home);
    }

    #[test]
    fn app_leftovers_skip_system_folders_and_installed_apps() {
        let home = fake_home("leftovers");
        let support = home.join("Library/Application Support");
        write_file(&support.join("com.google.Chrome/blob"), 25 * 1024 * 1024);
        write_file(&support.join("com.apple.Safari/blob"), 25 * 1024 * 1024);

        let items = Scanner::with_home(&home).scan_single_category(4);
        let ids: Vec<&str> = items.iter().map(|i| i.id.as_str()).collect();
        assert!(ids.contains(&"leftover_com.google.Chrome"), "{ids:?}");
        assert!(!ids.iter().any(|id| id.contains("Safari")), "{ids:?}");
        assert!(items.iter().all(|i| i.category == CleanCategory::AppLeftover));
        let _ = fs::remove_dir_all(&home);
    }

    #[test]
    fn full_scan_totals_match_the_items() {
        let home = fake_home("full");
        write_file(&home.join("Library/Caches/large/item"), 12 * 1024 * 1024);
        write_file(&home.join(".Trash/old"), 10);

        let report = Scanner::with_home(&home).run_full_scan();
        let expected: u64 = report.items.iter().map(|i| i.size_bytes).sum();
        assert_eq!(report.total_bytes, expected);
        assert!(report.items.len() >= 2);
        assert!(
            report.items.windows(2).all(|w| w[0].size_bytes >= w[1].size_bytes),
            "items are sorted by size descending"
        );
        let _ = fs::remove_dir_all(&home);
    }

    #[test]
    fn test_scanner_benchmark() {
        let scanner = Scanner::new();
        let report = scanner.run_full_scan();
        println!("\n=== SCAN BENCHMARK ===");
        println!("Items detected: {}", report.items.len());
        println!("Total cleanable: {:.2} MB", report.total_bytes as f64 / (1024.0 * 1024.0));
        println!("Scan Duration: {} ms", report.scan_duration_ms);
        for item in report.items.iter().take(5) {
            println!(" - [{:?}] {}: {:.1} MB ({})", item.category, item.name, item.size_bytes as f64 / (1024.0 * 1024.0), item.path);
        }
    }
}
