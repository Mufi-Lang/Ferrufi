use ferrufi_linux::ui::run_ui;

fn main() {
    println!("🚀 Starting Ferrufi Linux...");
    // In a real app, this would come from args or config
    run_ui(".".to_string());
}
