use serde::{Deserialize, Serialize};

/// High-level categories that non-technical users can understand.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum CleanCategory {
    UserCache,
    Developer,
    SystemLog,
    Trash,
    AppLeftover,
    ContainerStorage,
    MailDownloads,
    StaleDownloads,
}

impl CleanCategory {
    pub fn from_code(code: i32) -> Option<Self> {
        match code {
            0 => Some(Self::UserCache),
            1 => Some(Self::Developer),
            2 => Some(Self::SystemLog),
            3 => Some(Self::Trash),
            4 => Some(Self::AppLeftover),
            5 => Some(Self::ContainerStorage),
            6 => Some(Self::MailDownloads),
            7 => Some(Self::StaleDownloads),
            _ => None,
        }
    }

    pub fn default_selected(&self) -> bool {
        matches!(self, Self::UserCache | Self::SystemLog | Self::Trash)
    }

    pub fn is_advanced(&self) -> bool {
        !matches!(
            self,
            Self::UserCache | Self::SystemLog | Self::Trash | Self::AppLeftover
        )
    }
}

/// A specific target identified for cleaning.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CleanItem {
    pub id: String,
    pub name: String,
    pub path: String,
    pub size_bytes: u64,
    pub category: CleanCategory,
    pub description: String,
    pub is_default_selected: bool,
}

/// Overall report generated after scanning.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ScanReport {
    pub items: Vec<CleanItem>,
    pub total_bytes: u64,
    pub scan_duration_ms: u64,
}

/// Result of trashing items.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TrashResult {
    pub success: bool,
    pub trashed_paths: Vec<String>,
    pub failed_paths: Vec<String>,
    pub error_message: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_selection_matches_policy() {
        assert!(CleanCategory::UserCache.default_selected());
        assert!(CleanCategory::SystemLog.default_selected());
        assert!(CleanCategory::Trash.default_selected());
        assert!(!CleanCategory::Developer.default_selected());
        assert!(!CleanCategory::StaleDownloads.default_selected());
    }

    #[test]
    fn advanced_categories_are_opt_in() {
        assert!(!CleanCategory::AppLeftover.is_advanced());
        assert!(CleanCategory::Developer.is_advanced());
        assert!(CleanCategory::ContainerStorage.is_advanced());
    }

    #[test]
    fn serializes_items_as_camel_case() {
        let item = CleanItem {
            id: "cache_x".into(),
            name: "Cache: x".into(),
            path: "/tmp/x".into(),
            size_bytes: 42,
            category: CleanCategory::UserCache,
            description: "d".into(),
            is_default_selected: true,
        };
        let json = serde_json::to_string(&item).unwrap();
        assert!(json.contains("\"sizeBytes\":42"));
        assert!(json.contains("\"isDefaultSelected\":true"));
        assert!(json.contains("\"category\":\"userCache\""));
        let round_trip: CleanItem = serde_json::from_str(&json).unwrap();
        assert_eq!(round_trip.size_bytes, 42);
    }
}
