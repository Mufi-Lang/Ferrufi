import CMufi
import Foundation

/// A service that wraps Mufi C runtime calls for project management and formatting.
/// Provides a higher-level Swift API over MufiBridge and the underlying C library.
public actor MufiRuntimeService {
    public static let shared = MufiRuntimeService()
    
    private init() {}
    
    /// Formats Mufi source code using the runtime's formatter.
    /// - Parameter source: The unformatted source code.
    /// - Returns: The formatted source code, or nil if formatting failed.
    public func formatSource(_ source: String) async throws -> String? {
        guard !source.isEmpty else { return source }
        
        return await Task.detached(priority: .userInitiated) {
            return source.withCString { cSource in
                guard let cFormatted = mufiz_format_source(cSource) else {
                    return nil
                }
                var formatted = String(cString: cFormatted)
                mufiz_free_cstring(cFormatted)
                
                // Workaround: Fix bug where 'print radius' is merged into 'printradius'
                // Search for 'print' followed by what looks like an identifier that was merged
                if formatted.contains("print") || formatted.contains("import") || formatted.contains("return") {
                    let keywords = ["print", "return", "var", "let", "fun", "class", "import"]
                    for kw in keywords {
                        let pattern = "\\b(\(kw))([a-zA-Z_][a-zA-Z0-9_]*)\\b"
                        if let regex = try? NSRegularExpression(pattern: pattern) {
                            formatted = regex.stringByReplacingMatches(
                                in: formatted,
                                options: [],
                                range: NSRange(location: 0, length: formatted.utf16.count),
                                withTemplate: "$1 $2"
                            )
                        }
                    }
                }
                
                return formatted
            }
        }.value
    }
    
    /// Creates a new Mufi project at the specified path.
    /// - Parameters:
    ///   - name: The name of the project.
    ///   - path: The filesystem path where the project should be created.
    ///   - initGit: Whether to initialize a git repository in the new directory.
    public func createNewProject(name: String, at path: String, initGit: Bool = false) async throws {
        let fileManager = FileManager.default
        let projectURL = URL(fileURLWithPath: path).appendingPathComponent(name)
        let projectPath = projectURL.path
        
        // 1. Create the directory manually (more robust for sandboxing)
        if !fileManager.fileExists(atPath: projectPath) {
            try fileManager.createDirectory(atPath: projectPath, withIntermediateDirectories: true)
        }
        
        // 2. Initialize the project in that directory using mufiz_pm_init
        let rc = await Task.detached(priority: .userInitiated) {
            let previousPath = fileManager.currentDirectoryPath
            fileManager.changeCurrentDirectoryPath(projectPath)
            defer { fileManager.changeCurrentDirectoryPath(previousPath) }
            
            return name.withCString { cName in
                return mufiz_pm_init(cName)
            }
        }.value
        
        if rc != MUFIZ_OK {
            throw MufiError.initializationFailed(code: rc)
        }
        
        if initGit {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["init"]
            process.currentDirectoryURL = projectURL
            try process.run()
            process.waitUntilExit()
        }
    }
    
    /// Runs the project in the current or specified directory.
    public func runProject(at path: String) async throws -> (Int32, String) {
        return await Task.detached(priority: .userInitiated) {
            let previousPath = FileManager.default.currentDirectoryPath
            FileManager.default.changeCurrentDirectoryPath(path)
            defer { FileManager.default.changeCurrentDirectoryPath(previousPath) }
            
            return self.captureOutput {
                return mufiz_pm_run()
            }
        }.value
    }
    
    /// Installs project dependencies.
    public func installDependencies(at path: String) async throws -> (Int32, String) {
        return await Task.detached(priority: .userInitiated) {
            let previousPath = FileManager.default.currentDirectoryPath
            FileManager.default.changeCurrentDirectoryPath(path)
            defer { FileManager.default.changeCurrentDirectoryPath(previousPath) }
            
            return self.captureOutput {
                return mufiz_pm_install()
            }
        }.value
    }
    
    /// Adds a dependency to the project.
    public func addDependency(at path: String, name: String, url: String, version: String) async throws -> (Int32, String) {
        return await Task.detached(priority: .userInitiated) {
            let previousPath = FileManager.default.currentDirectoryPath
            FileManager.default.changeCurrentDirectoryPath(path)
            defer { FileManager.default.changeCurrentDirectoryPath(previousPath) }
            
            return self.captureOutput {
                return name.withCString { cName in
                    url.withCString { cUrl in
                        version.withCString { cVersion in
                            return mufiz_pm_add_dependency(cName, cUrl, cVersion)
                        }
                    }
                }
            }
        }.value
    }
    
    /// Generates project documentation.
    public func generateDocs(at path: String) async throws -> (Int32, String) {
        return await Task.detached(priority: .userInitiated) {
            let previousPath = FileManager.default.currentDirectoryPath
            FileManager.default.changeCurrentDirectoryPath(path)
            defer { FileManager.default.changeCurrentDirectoryPath(previousPath) }
            
            return self.captureOutput {
                return mufiz_pm_docs()
            }
        }.value
    }

    /// Internal helper to capture stdout/stderr for synchronous C calls.
    nonisolated private func captureOutput<T>(_ body: () -> T) -> (T, String) {
        var fds: [Int32] = [0, 0]
        guard pipe(&fds) == 0 else { return (body(), "") }
        let readFD = fds[0]
        let writeFD = fds[1]
        let savedStdout = dup(STDOUT_FILENO)
        let savedStderr = dup(STDERR_FILENO)
        
        guard savedStdout >= 0, savedStderr >= 0 else {
            close(readFD); close(writeFD)
            return (body(), "")
        }
        
        fflush(stdout); fflush(stderr)
        dup2(writeFD, STDOUT_FILENO)
        dup2(writeFD, STDERR_FILENO)
        close(writeFD)
        
        let result = body()
        
        fflush(stdout); fflush(stderr)
        dup2(savedStdout, STDOUT_FILENO)
        dup2(savedStderr, STDERR_FILENO)
        close(savedStdout); close(savedStderr)
        
        var output = String()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        
        while true {
            let bytesRead = read(readFD, buffer, bufferSize)
            if bytesRead > 0 {
                let data = Data(bytes: buffer, count: Int(bytesRead))
                output.append(String(decoding: data, as: UTF8.self))
            } else { break }
        }
        close(readFD)
        return (result, output)
    }
}
