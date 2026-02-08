use adw::prelude::*;
use adw::{Application, ApplicationWindow, HeaderBar, NavigationSplitView, NavigationPage};
use gtk4::{Label, ListBox, Box, Orientation, ScrolledWindow, PolicyType, SelectionMode, TextView, Button};
use std::sync::{Arc, Mutex};
use crate::workspace::WorkspaceManager;
use crate::MufiBridge;
use uuid::Uuid;

pub struct AppState {
    pub workspace: WorkspaceManager,
    pub bridge: Option<MufiBridge>,
    pub selected_folder_id: Option<Uuid>,
    pub selected_note_id: Option<Uuid>,
}

pub fn run_ui(initial_path: String) {
    // Initialize bridge if possible
    let bridge = unsafe {
        let lib_path = if std::path::Path::new("./libmufiz.so").exists() {
            "./libmufiz.so"
        } else if std::path::Path::new("/usr/local/lib/libmufiz.so").exists() {
            "/usr/local/lib/libmufiz.so"
        } else {
            "/src/Sources/CMufi/libmufiz.so"
        };
        
        MufiBridge::new(lib_path).ok()
    };

    if let Some(ref b) = bridge {
        let _ = b.init(true, true, true);
    }

    let state = Arc::new(Mutex::new(AppState {
        workspace: WorkspaceManager::new(initial_path),
        bridge,
        selected_folder_id: None,
        selected_note_id: None,
    }));

    let app = Application::builder()
        .application_id("com.mustafif.ferrufi")
        .build();

    app.connect_activate(move |app| {
        build_ui(app, state.clone());
    });

    app.run();
}

fn build_ui(app: &Application, state: Arc<Mutex<AppState>>) {
    // 1. Initialize Workspace
    {
        let mut state_lock = state.lock().unwrap();
        let _ = tokio::runtime::Runtime::new().unwrap().block_on(state_lock.workspace.refresh());
    }

    // --- Components ---

    // A. Editor (Right Pane)
    let editor_view = sourceview5::View::builder()
        .monospace(true)
        .top_margin(12)
        .left_margin(12)
        .right_margin(12)
        .bottom_margin(12)
        .build();
    
    let editor_scroll = ScrolledWindow::builder()
        .vexpand(true)
        .child(&editor_view)
        .build();

    // REPL Output
    let repl_output = TextView::builder()
        .editable(false)
        .monospace(true)
        .css_classes(["repl-output"])
        .build();
    
    let repl_scroll = ScrolledWindow::builder()
        .height_request(200)
        .child(&repl_output)
        .build();

    let editor_vbox = Box::new(Orientation::Vertical, 0);
    
    let header = HeaderBar::new();
    let run_button = Button::builder()
        .label("Run")
        .css_classes(["suggested-action"])
        .build();
    header.pack_start(&run_button);
    
    editor_vbox.append(&header);
    editor_vbox.append(&editor_scroll);
    editor_vbox.append(&gtk4::Separator::new(Orientation::Horizontal));
    editor_vbox.append(&repl_scroll);

    let editor_page = NavigationPage::new(&editor_vbox, "Editor");

    // B. Note List (Middle Pane)
    let note_list = ListBox::builder()
        .selection_mode(SelectionMode::Single)
        .build();
    
    let note_list_scroll = ScrolledWindow::builder()
        .hscrollbar_policy(PolicyType::Never)
        .child(&note_list)
        .build();

    let note_list_container = Box::new(Orientation::Vertical, 0);
    note_list_container.append(&HeaderBar::new());
    note_list_container.append(&note_list_scroll);
    let note_list_page = NavigationPage::new(&note_list_container, "Notes");

    // C. Folder List (Left Pane)
    let folder_list = ListBox::builder()
        .selection_mode(SelectionMode::Single)
        .css_classes(["navigation-sidebar"])
        .build();

    let folder_list_scroll = ScrolledWindow::builder()
        .hscrollbar_policy(PolicyType::Never)
        .child(&folder_list)
        .build();
    let folder_list_page = NavigationPage::new(&folder_list_scroll, "Folders");

    // --- Layout ---

    // Inner split: Note List | Editor
    let inner_split = NavigationSplitView::builder()
        .sidebar(&note_list_page)
        .content(&editor_page)
        .min_sidebar_width(250.0)
        .build();

    let inner_split_page = NavigationPage::new(&inner_split, "Content");

    // Outer split: Folders | (Notes | Editor)
    let outer_split = NavigationSplitView::builder()
        .sidebar(&folder_list_page)
        .content(&inner_split_page)
        .min_sidebar_width(200.0)
        .build();

    // --- Data Binding & Signals ---

    // Run Button Logic
    let state_run = state.clone();
    let editor_buffer = editor_view.buffer();
    let repl_buffer = repl_output.buffer();
    run_button.connect_clicked(move |_| {
        let state_lock = state_run.lock().unwrap();
        if let Some(ref bridge) = state_lock.bridge {
            let start = editor_buffer.start_iter();
            let end = editor_buffer.end_iter();
            let code = editor_buffer.text(&start, &end, false);
            
            match bridge.interpret_with_output(&code) {
                Ok((_status, output)) => {
                    repl_buffer.set_text(&output);
                }
                Err(e) => {
                    repl_buffer.set_text(&format!("Error: {}", e));
                }
            }
        } else {
            repl_buffer.set_text("MufiZ Runtime not loaded");
        }
    });

    // Populate Folders
    {
        let state_lock = state.lock().unwrap();
        for folder in state_lock.workspace.all_folders() {
            let row = Box::new(Orientation::Horizontal, 10);
            row.set_widget_name(&folder.id.to_string());
            let label = Label::new(Some(&folder.name));
            row.append(&label);
            folder_list.append(&row);
        }
    }

    // Folder selection handler
    let state_clone = state.clone();
    let note_list_clone = note_list.clone();
    folder_list.connect_row_selected(move |_, row| {
        if let Some(row) = row {
            let folder_id_str = row.child().unwrap().widget_name();
            if let Ok(folder_id) = Uuid::parse_str(&folder_id_str) {
                let mut state_lock = state_clone.lock().unwrap();
                state_lock.selected_folder_id = Some(folder_id);
                
                while let Some(child) = note_list_clone.first_child() {
                    note_list_clone.remove(&child);
                }

                for note in state_lock.workspace.all_notes() {
                    let note_row = Box::new(Orientation::Horizontal, 10);
                    note_row.set_widget_name(&note.id.to_string());
                    note_row.append(&Label::new(Some(&note.title)));
                    note_list_clone.append(&note_row);
                }
            }
        }
    });

    // Note selection handler
    let state_clone_2 = state.clone();
    let editor_view_clone = editor_view.clone();
    note_list.connect_row_selected(move |_, row| {
        if let Some(row) = row {
            let note_id_str = row.child().unwrap().widget_name();
            if let Ok(note_id) = Uuid::parse_str(&note_id_str) {
                let state_lock = state_clone_2.lock().unwrap();
                if let Some(note) = state_lock.workspace.all_notes().iter().find(|n| n.id == note_id) {
                    editor_view_clone.buffer().set_text(&note.content);
                }
            }
        }
    });

    // --- Main Window ---
    let window = ApplicationWindow::builder()
        .application(app)
        .title("Ferrufi")
        .default_width(1100)
        .default_height(750)
        .content(&outer_split)
        .build();

    window.present();
}
