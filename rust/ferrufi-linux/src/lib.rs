use std::ffi::CString;
use std::os::raw::c_char;
use libloading::{Library, Symbol};
use std::sync::Arc;
use std::io::Read;
use std::fs::File;
use std::os::unix::io::FromRawFd;

pub mod models;
pub mod workspace;
pub mod ui;

// --- Mufiz ABI Types ---

#[repr(C)]
pub struct MufizPosition {
    pub line: u32,
    pub column: u32,
}

#[repr(C)]
pub struct MufizRange {
    pub start: MufizPosition,
    pub end: MufizPosition,
}

#[repr(C)]
pub struct MufizDiagnostic {
    pub range: MufizRange,
    pub severity: i32, // 1=Error, 2=Warning
    pub message: *const c_char,
}

#[repr(C)]
pub struct MufizCompletionItem {
    pub name: *const c_char,
    pub type_name: *const c_char,
    pub doc_string: *const c_char,
    pub kind: u8, // 1=Variable, 2=Function, 3=Struct
}

// --- Bridge implementation ---

pub struct MufiBridge {
    lib: Arc<Library>,
}

impl MufiBridge {
    pub unsafe fn new(lib_path: &str) -> Result<Self, Box<dyn std::error::Error>> {
        let lib = Arc::new(Library::new(lib_path)?);
        Ok(Self { lib })
    }

    pub fn init(&self, leak_detect: bool, tracking: bool, safety: bool) -> Result<i32, Box<dyn std::error::Error>> {
        unsafe {
            let func: Symbol<unsafe extern "C" fn(bool, bool, bool) -> i32> = self.lib.get(b"mufiz_init")?;
            Ok(func(leak_detect, tracking, safety))
        }
    }

    pub fn deinit(&self) {
        unsafe {
            if let Ok(func) = self.lib.get::<unsafe extern "C" fn()>(b"mufiz_deinit") {
                func();
            }
        }
    }

    pub fn interpret_with_output(&self, code: &str) -> Result<(u8, String), Box<dyn std::error::Error>> {
        unsafe {
            let mut pipe_fds = [0i32; 2];
            if libc::pipe(pipe_fds.as_mut_ptr()) < 0 {
                return Err("Failed to create pipe".into());
            }

            let original_stdout = libc::dup(libc::STDOUT_FILENO);
            let original_stderr = libc::dup(libc::STDERR_FILENO);

            libc::dup2(pipe_fds[1], libc::STDOUT_FILENO);
            libc::dup2(pipe_fds[1], libc::STDERR_FILENO);

            let func: Symbol<unsafe extern "C" fn(*const c_char) -> u8> = self.lib.get(b"mufiz_interpret")?;
            let c_code = CString::new(code)?;
            let status = func(c_code.as_ptr());

            libc::fflush(std::ptr::null_mut()); // Flush all streams
            
            libc::dup2(original_stdout, libc::STDOUT_FILENO);
            libc::dup2(original_stderr, libc::STDERR_FILENO);
            libc::close(pipe_fds[1]);
            libc::close(original_stdout);
            libc::close(original_stderr);

            let mut output = String::new();
            let mut reader = File::from_raw_fd(pipe_fds[0]);
            
            let mut buffer = [0u8; 4096];
            loop {
                let mut pfd = libc::pollfd { fd: pipe_fds[0], events: libc::POLLIN, revents: 0 };
                match libc::poll(&mut pfd, 1, 100) {
                    1 => {
                        let n = reader.read(&mut buffer)?;
                        if n == 0 { break; }
                        output.push_str(&String::from_utf8_lossy(&buffer[..n]));
                    }
                    _ => break,
                }
            }

            Ok((status, output))
        }
    }

    pub fn interpret(&self, code: &str) -> Result<u8, Box<dyn std::error::Error>> {
        unsafe {
            let func: Symbol<unsafe extern "C" fn(*const c_char) -> u8> = self.lib.get(b"mufiz_interpret")?;
            let c_code = CString::new(code)?;
            Ok(func(c_code.as_ptr()))
        }
    }

    pub fn has_memory_leaks(&self) -> bool {
        unsafe {
            if let Ok(func) = self.lib.get::<unsafe extern "C" fn() -> bool>(b"mufiz_has_memory_leaks") {
                func()
            } else {
                false
            }
        }
    }

    pub fn print_memory_stats(&self) {
        unsafe {
            if let Ok(func) = self.lib.get::<unsafe extern "C" fn()>(b"mufiz_print_memory_stats") {
                func();
            }
        }
    }
}
