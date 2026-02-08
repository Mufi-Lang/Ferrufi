use crate::models::{Note, Folder, NoteMetadata, FolderMetadata};
use std::path::{Path, PathBuf};
use std::fs;
use std::collections::{HashMap, HashSet};
use uuid::Uuid;
use chrono::{DateTime, Utc};
use walkdir::WalkDir;
use std::io;

pub struct WorkspaceManager {
    root_path: PathBuf,
    folders: HashMap<Uuid, Folder>,
    notes: HashMap<Uuid, Note>,
}

impl WorkspaceManager {
    pub fn new<P: AsRef<Path>>(path: P) -> Self {
        Self {
            root_path: path.as_ref().to_path_buf(),
            folders: HashMap::new(),
            notes: HashMap::new(),
        }
    }

    pub async fn refresh(&mut self) -> io::Result<()> {
        self.folders.clear();
        self.notes.clear();

        // 1. Create root folder entry
        let root_id = Uuid::new_v4();
        let root_folder = Folder {
            id: root_id,
            name: self.root_path.file_name().unwrap_or_default().to_string_lossy().into_owned(),
            path: self.root_path.to_string_lossy().into_owned(),
            parent_id: None,
            created_at: Utc::now(),
            modified_at: Utc::now(),
            metadata: FolderMetadata::default(),
        };
        self.folders.insert(root_id, root_folder);

        // 2. Scan filesystem
        let mut path_to_id = HashMap::new();
        path_to_id.insert(self.root_path.clone(), root_id);

        for entry in WalkDir::new(&self.root_path)
            .min_depth(1)
            .into_iter()
            .filter_map(|e| e.ok()) {
            
            let path = entry.path();
            let parent_path = path.parent().unwrap();
            let parent_id = path_to_id.get(parent_path).cloned();

            if entry.file_type().is_dir() {
                if entry.file_name() == ".metadata" {
                    continue;
                }

                let id = Uuid::new_v4();
                let folder = Folder {
                    id,
                    name: entry.file_name().to_string_lossy().into_owned(),
                    path: path.to_string_lossy().into_owned(),
                    parent_id,
                    created_at: Utc::now(), // In a real app, read from filesystem or metadata
                    modified_at: Utc::now(),
                    metadata: FolderMetadata::default(),
                };
                self.folders.insert(id, folder);
                path_to_id.insert(path.to_path_buf(), id);
            } else if entry.file_type().is_file() {
                let extension = path.extension().and_then(|s| s.to_str()).unwrap_or("");
                if extension == "mufi" || extension == "md" {
                    if let Ok(note) = self.load_note_from_disk(path).await {
                        self.notes.insert(note.id, note);
                    }
                }
            }
        }

        Ok(())
    }

    async fn load_note_from_disk(&self, path: &Path) -> io::Result<Note> {
        let content = fs::read_to_string(path)?;
        let metadata = fs::metadata(path)?;
        
        let created_at: DateTime<Utc> = metadata.created().unwrap_or(std::time::SystemTime::now()).into();
        let modified_at: DateTime<Utc> = metadata.modified().unwrap_or(std::time::SystemTime::now()).into();

        // Check for .metadata shadow file to preserve UUIDs and other metadata
        let note_id = self.discover_note_id(path).unwrap_or_else(Uuid::new_v4);

        Ok(Note {
            id: note_id,
            title: path.file_stem().unwrap_or_default().to_string_lossy().into_owned(),
            content,
            tags: HashSet::new(), // Parse from content if needed
            created_at,
            modified_at,
            file_path: path.to_string_lossy().into_owned(),
            metadata: NoteMetadata::default(),
        })
    }

    fn discover_note_id(&self, _path: &Path) -> Option<Uuid> {
        // Implementation for reading from .metadata/*.json
        None
    }

    pub fn all_notes(&self) -> Vec<&Note> {
        self.notes.values().collect()
    }

    pub fn all_folders(&self) -> Vec<&Folder> {
        self.folders.values().collect()
    }
}
