use serde::{Deserialize, Serialize};
use uuid::Uuid;
use chrono::{DateTime, Utc};
use std::collections::{HashSet, HashMap};

// --- Note Models ---

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Note {
    pub id: Uuid,
    pub title: String,
    pub content: String,
    pub tags: HashSet<String>,
    pub created_at: DateTime<Utc>,
    pub modified_at: DateTime<Utc>,
    pub file_path: String,
    pub metadata: NoteMetadata,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct NoteMetadata {
    pub is_favorite: bool,
    pub is_archived: bool,
    pub is_pinned: bool,
    pub custom_properties: HashMap<String, String>,
}

impl Default for NoteMetadata {
    fn default() -> Self {
        Self {
            is_favorite: false,
            is_archived: false,
            is_pinned: false,
            custom_properties: HashMap::new(),
        }
    }
}

// --- Folder Models ---

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Folder {
    pub id: Uuid,
    pub name: String,
    pub path: String,
    pub parent_id: Option<Uuid>,
    pub created_at: DateTime<Utc>,
    pub modified_at: DateTime<Utc>,
    pub metadata: FolderMetadata,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct FolderMetadata {
    pub is_expanded: bool,
    pub sort_order: FolderSortOrder,
    pub color: Option<String>,
    pub icon: Option<String>,
    pub custom_properties: HashMap<String, String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum FolderSortOrder {
    Name,
    DateCreated,
    DateModified,
    Size,
    Custom,
}

impl Default for FolderMetadata {
    fn default() -> Self {
        Self {
            is_expanded: true,
            sort_order: FolderSortOrder::Name,
            color: None,
            icon: None,
            custom_properties: HashMap::new(),
        }
    }
}
