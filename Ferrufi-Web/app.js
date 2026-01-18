// Small notebook runtime for running mufiz wasm module code blocks.
//
// Assumptions:
// - `../lib/mufiz.js` is included first in the HTML (this file uses the global Module factory created by that script).
// - `mufiz.wasm` is next to mufiz.js in ../lib/ so the glue can find it.

(async function () {
  // Elements (core UI hooks)
  const notebook = document.getElementById("notebook");
  const addCellBtn = document.getElementById("add-cell");
  const runAllBtn = document.getElementById("run-all");
  const themeSelector =
    document.getElementById("theme-selector") ||
    document.getElementById("theme-select");
  const kernelStatus = document.getElementById("kernel-status");
  const cellTemplate = document.getElementById("cell-template");

  // IDE / Files UI hooks
  const viewFilesBtn = document.getElementById("view-files");
  const viewNotebookBtn = document.getElementById("view-notebook");
  const newFileBtn = document.getElementById("new-file");
  const fileListEl = document.getElementById("file-list");
  const fileTabsEl = document.getElementById("file-tabs");
  const fileEditorEl = document.getElementById("file-editor");
  const filesArea = document.getElementById("files-area");
  const notebookArea = document.getElementById("notebook-area");
  const runFileBtn = document.getElementById("run-file");
  const saveFileBtn = document.getElementById("save-file");
  const restartKernelBtn = document.getElementById("restart-kernel");
  const toggleConsoleBtn = document.getElementById("toggle-console");
  const consoleOutput = document.getElementById("console-output");
  const ideConsole = document.getElementById("ide-console");
  const clearConsoleBtn = document.getElementById("clear-console");
  const kernelStateEl = document.getElementById("kernel-state");

  // Module instance (the Emscripten-module factory exported by mufiz.js is a function returning a Promise)
  let moduleInstance = null;
  let api = null; // wrapper for calling mufiz functions
  // Execution counter for In/Out prompts (In [n] / Out [n])
  let execCounter = 1;

  // Initialize module once at startup (remote server-backed)
  async function initModule() {
    if (moduleInstance) return api;

    // We no longer instantiate a local wasm module in the browser.
    // Instead create a small wrapper that talks to the dev server (/api/interpret).
    let currentOutputTarget = null;

    api = createApiWrapper(null, {
      setCurrentOutputTarget(target) {
        currentOutputTarget = target;
      },
      _getOutputTarget() {
        return currentOutputTarget;
      },
    });

    // Lightweight diagnostics used by the UI
    api._diagnostics = api._diagnostics || {};
    api._diagnostics.remote = true;
    api._diagnostics.backend = "/api/interpret";
    api._diagnostics.foundInterpret = true;

    // Keep a no-op init shim for compatibility (optionally forwards to server)
    if (!api.init) {
      api.init = async function (a = 0, b = 0, c = 1) {
        try {
          // Best-effort initialize on server (server may ignore this)
          await fetch("/api/init", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ a, b, c }),
          }).catch(() => {});
          return 0;
        } catch (e) {
          return -1;
        }
      };
    }

    // indicate native backend is available (server-backed via bun:ffi)
    try {
      if (kernelStatus) kernelStatus.textContent = "Native (Bun) Ready";
    } catch (e) {}
    return api;
  }

  // Theme handling: read/save current theme and wire dropdown (if present).
  // Uses localStorage key 'ferrufi_theme' and applies it as body[data-theme="<name>"].
  function applyTheme(name) {
    if (!name) return;
    try {
      document.body.setAttribute("data-theme", name);
    } catch (e) {}
    try {
      localStorage.setItem("ferrufi_theme", name);
    } catch (e) {}
    if (typeof themeSelector !== "undefined" && themeSelector)
      themeSelector.value = name;

    // Refresh editors using a shared helper (delegates to refreshEditors)
    try {
      refreshEditors(name);
    } catch (err) {
      // ignore errors during editor refresh
    }
  }

  function initTheme() {
    const saved = (function () {
      try {
        return localStorage.getItem("ferrufi_theme");
      } catch (e) {
        return null;
      }
    })();
    const prefersDark =
      window.matchMedia &&
      window.matchMedia("(prefers-color-scheme: dark)").matches;
    const initial = saved || (prefersDark ? "dark" : "light");
    applyTheme(initial);
    if (typeof themeSelector !== "undefined" && themeSelector) {
      themeSelector.addEventListener("change", (e) =>
        applyTheme(e.target.value),
      );
    }
  }
  initTheme();

  // Initialize file workspace (load persisted files and render explorer)
  try {
    loadFiles();
    renderFileList();
  } catch (e) {
    // If file manager isn't ready yet, ignore and proceed (it will be initialized later)
    console.warn("file manager init skipped:", e && e.message ? e.message : e);
  }

  // Ensure CodeMirror is available (best-effort) and refresh/create editors in existing cells.
  async function ensureCMModuleLoaded() {
    if (typeof window.createEditor === "function") {
      window.updateEditorStatus && window.updateEditorStatus("ready");
      return true;
    }
    window.updateEditorStatus && window.updateEditorStatus("loading");
    try {
      if (typeof window.loadCodeMirror === "function") {
        await window.loadCodeMirror();
      } else {
        try {
          // Attempt a dynamic import of the module if possible.
          await import("./codemirror.js");
        } catch (e) {
          console.warn("dynamic import codemirror.js failed", e);
        }
      }
      const ok = typeof window.createEditor === "function";
      window.updateEditorStatus &&
        window.updateEditorStatus(ok ? "ready" : "error");
      return ok;
    } catch (e) {
      console.error("ensureCMModuleLoaded error", e);
      window.updateEditorStatus && window.updateEditorStatus("error");
      return false;
    }
  }

  // Recreate or create editors for all cells (preserve content).
  async function refreshEditors(theme) {
    const ok = await ensureCMModuleLoaded();
    if (!ok) return;
    const name = theme || document.body.getAttribute("data-theme") || null;
    const cells = Array.from(document.querySelectorAll(".cell"));
    for (const cell of cells) {
      try {
        const host = cell.querySelector(".editor");
        const fb = cell.querySelector("textarea.code");
        let content = "";
        if (cell._editor && typeof cell._editor.getValue === "function") {
          // preserve current content
          content = cell._editor.getValue();
          try {
            if (typeof cell._editor.destroy === "function")
              cell._editor.destroy();
          } catch (e) {
            /* ignore */
          }
        } else if (fb) {
          content = fb.value;
        }
        cell._editor = null;
        try {
          const newEd = await window.createEditor(host, {
            value: content,
            language: "javascript",
            theme: name,
            onRun: (selection) => {
              if (typeof cell._run === "function") cell._run(selection);
            },
          });
          cell._editor = newEd;
          if (fb) fb.style.display = "none";
          // notify other UI that editors are present
          window.dispatchEvent(
            new CustomEvent("ferrufi:editor-created", { detail: { cell } }),
          );
        } catch (e) {
          console.warn("refreshEditors: failed to create editor for cell", e);
          if (fb) fb.style.display = "";
        }
      } catch (e) {
        console.warn("refreshEditors: cell refresh error", e);
      }
    }
  }

  // Listen for reload events dispatched by the UI and refresh editors
  window.addEventListener("ferrufi:reload-editors", async () => {
    window.updateEditorStatus && window.updateEditorStatus("reloading");
    await refreshEditors();
    window.updateEditorStatus && window.updateEditorStatus("ready");
  });

  // Warm-up: attempt to load CodeMirror and create editors for any existing cells
  (async function initialEditorWarmup() {
    try {
      await ensureCMModuleLoaded();
      await refreshEditors();
    } catch (e) {
      console.warn("initialEditorWarmup failed", e);
    }

    // Wire IDE controls (view toggles, file actions, console)
    try {
      // View toggles: Files vs Notebook
      if (viewFilesBtn && viewNotebookBtn && filesArea && notebookArea) {
        viewFilesBtn.addEventListener("click", () => {
          filesArea.classList.remove("hidden");
          filesArea.setAttribute("aria-hidden", "false");
          notebookArea.classList.add("hidden");
          notebookArea.setAttribute("aria-hidden", "true");
          viewFilesBtn.classList.add("active");
          viewNotebookBtn.classList.remove("active");
        });
        viewNotebookBtn.addEventListener("click", () => {
          filesArea.classList.add("hidden");
          filesArea.setAttribute("aria-hidden", "true");
          notebookArea.classList.remove("hidden");
          notebookArea.setAttribute("aria-hidden", "false");
          viewFilesBtn.classList.remove("active");
          viewNotebookBtn.classList.add("active");
        });
      }

      // New file / folder / upload handlers
      if (newFileBtn) {
        newFileBtn.addEventListener("click", async () => {
          const name = prompt(
            "New file name",
            `untitled_${Date.now().toString(36).slice(-4)}.muf`,
          );
          if (!name) return;
          try {
            // Create locally and try to persist on server workspace as well.
            const f = createFile(name, defaultFileTemplate());
            openFile(name);
            appendToConsole(`Created file: ${name}`);
            try {
              const res = await fetch("/api/workspace/write", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ path: name, content: f.content }),
              });
              if (!res.ok) {
                appendToConsole(
                  `[warn] server workspace write failed (${res.status})`,
                );
              }
            } catch (e) {
              appendToConsole(
                `[warn] server workspace write unavailable: ${e && e.message ? e.message : e}`,
              );
            }
          } catch (e) {
            appendToConsole(
              `[error] Could not create file: ${e && e.message ? e.message : e}`,
            );
          }
        });
      }
      // New folder
      const newFolderBtn = document.getElementById("new-folder");
      if (newFolderBtn) {
        newFolderBtn.addEventListener("click", async () => {
          const name = prompt(
            "New folder name (relative to workspace root):",
            `new_folder_${Date.now().toString(36).slice(-4)}`,
          );
          if (!name) return;
          try {
            // Try server mkdir first
            try {
              const res = await fetch("/api/workspace/mkdir", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ path: name, recursive: true }),
              });
              if (!res.ok) {
                appendToConsole(`[warn] server mkdir failed (${res.status})`);
              } else {
                appendToConsole(`Created folder (server): ${name}`);
              }
            } catch (e) {
              appendToConsole(
                `[warn] server mkdir unavailable: ${e && e.message ? e.message : e}`,
              );
            }
            // Refresh file list (server list will update if available)
            try {
              // best-effort refresh from server
              const listRes = await fetch("/api/workspace/list?path=.");
              if (listRes.ok) {
                const js = await listRes.json();
                // Let loadFiles/background fetch handle updating `files`; simple rerender for now
                loadFiles();
              } else {
                renderFileList();
              }
            } catch (_) {
              renderFileList();
            }
          } catch (e) {
            appendToConsole(
              `[error] Could not create folder: ${e && e.message ? e.message : e}`,
            );
          }
        });
      }
      // Upload file
      const uploadBtn = document.getElementById("upload-file");
      if (uploadBtn) {
        uploadBtn.addEventListener("click", () => {
          // create a hidden file input and trigger it
          const input = document.createElement("input");
          input.type = "file";
          input.multiple = false;
          input.onchange = async (ev) => {
            const f = input.files && input.files[0];
            if (!f) return;
            const reader = new FileReader();
            reader.onload = async () => {
              const content =
                typeof reader.result === "string" ? reader.result : "";
              const name = f.name;
              try {
                // persist locally
                const created = createFile(name, content);
                openFile(name);
                appendToConsole(`Uploaded: ${name}`);
                // attempt server write
                try {
                  await fetch("/api/workspace/write", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ path: name, content }),
                  });
                } catch (e) {
                  appendToConsole(
                    `[warn] upload: server write failed: ${e && e.message ? e.message : e}`,
                  );
                }
              } catch (e) {
                appendToConsole(
                  `[error] upload failed: ${e && e.message ? e.message : e}`,
                );
              }
            };
            reader.readAsText(f);
          };
          input.click();
        });
      }

      // Run / Save file buttons
      if (runFileBtn) {
        runFileBtn.addEventListener("click", () => {
          try {
            runCurrentFile();
          } catch (e) {
            appendToConsole(`[error] run failed: ${String(e)}`);
          }
        });
      }
      if (saveFileBtn) {
        saveFileBtn.addEventListener("click", () => {
          try {
            saveCurrentFile();
            appendToConsole("File saved.");
          } catch (e) {
            appendToConsole(`[error] save failed: ${String(e)}`);
          }
        });
      }

      // Console toggle & controls + console tab switching
      if (toggleConsoleBtn) {
        toggleConsoleBtn.addEventListener("click", () => {
          if (!ideConsole) return;
          ideConsole.classList.toggle("hidden");
        });
      }
      if (clearConsoleBtn) {
        clearConsoleBtn.addEventListener("click", () => {
          if (consoleOutput) consoleOutput.textContent = "";
          const kernelOut = document.getElementById("kernel-output");
          if (kernelOut) kernelOut.textContent = "";
          // clear problems too
          const problems = document.getElementById("problems-list");
          if (problems) problems.innerHTML = "";
        });
      }

      // Console tabs: switch between Console / Kernel / Problems panels
      (function initConsoleTabs() {
        try {
          const tabs = Array.from(document.querySelectorAll(".console-tab"));
          const panels = Array.from(
            document.querySelectorAll(".console-panel"),
          );

          function showPanel(name) {
            panels.forEach((p) => {
              if (p.dataset && p.dataset.panel === name)
                p.classList.remove("hidden");
              else p.classList.add("hidden");
            });
            tabs.forEach((t) => {
              if (t.dataset && t.dataset.tab === name)
                t.classList.add("active");
              else t.classList.remove("active");
            });
          }

          tabs.forEach((t) => {
            t.addEventListener("click", (ev) => {
              ev.preventDefault();
              const name = t.dataset && t.dataset.tab ? t.dataset.tab : null;
              if (!name) return;
              showPanel(name);
            });
          });

          // When console is toggled visible, ensure the active tab panel is shown.
          // Default to 'console' tab
          showPanel("console");

          // Expose helper to other parts of the app
          window.ferrufiShowConsolePanel = showPanel;

          // --- Kernel SSE: listen to server-sent events for kernel/job streaming ---
          // Uses the /api/kernel/events SSE endpoint added on the server.
          // Appends kernel stdout/stderr/job events to the kernel panel and updates kernel status.
          function initKernelSSE() {
            try {
              if (typeof EventSource === "undefined") {
                console.warn("SSE not available in this environment");
                return;
              }
              // avoid double-init
              if (window._ferrufiKernelSSE) return;
              const es = new EventSource("/api/kernel/events");
              window._ferrufiKernelSSE = es;

              const kernelStateEl = document.getElementById("kernel-state");
              const kernelOutEl = document.getElementById("kernel-output");
              const consoleOutEl = document.getElementById("console-output");

              function appendKernel(msg) {
                try {
                  if (kernelOutEl) {
                    kernelOutEl.textContent += String(msg) + "\n";
                    kernelOutEl.scrollTop = kernelOutEl.scrollHeight;
                  }
                } catch (e) {}
              }

              es.onmessage = (ev) => {
                if (!ev || !ev.data) return;
                let obj = null;
                try {
                  obj = JSON.parse(ev.data);
                } catch (e) {
                  // not JSON; append raw
                  appendKernel(ev.data);
                  return;
                }

                // Top-level kernel events
                try {
                  if (obj.type === "kernel") {
                    const evName = obj.event || "unknown";
                    if (kernelStateEl) {
                      kernelStateEl.textContent = `Kernel: ${evName}`;
                    }
                    appendKernel(
                      `[kernel] ${evName}${obj.error ? " - " + obj.error : ""}`,
                    );
                    return;
                  }
                } catch (e) {}

                // Job-scoped events
                try {
                  if (obj.type === "job") {
                    const id = obj.id || "<unknown>";
                    const evt = obj.event || "";
                    switch (evt) {
                      case "start":
                        appendKernel(`[job ${id}] START`);
                        // also surface to main console
                        if (consoleOutEl)
                          consoleOutEl.textContent += `[job ${id}] START\n`;
                        break;
                      case "stdout":
                        if (obj.chunk) {
                          appendKernel(`[job ${id}] stdout: ${obj.chunk}`);
                          if (consoleOutEl)
                            consoleOutEl.textContent += obj.chunk + "\n";
                        }
                        break;
                      case "stderr":
                        if (obj.chunk) {
                          appendKernel(`[job ${id}] stderr: ${obj.chunk}`);
                          if (consoleOutEl)
                            consoleOutEl.textContent += `[stderr] ${obj.chunk}\n`;
                        }
                        break;
                      case "end":
                        appendKernel(
                          `[job ${id}] END (rc=${typeof obj.rc !== "undefined" ? obj.rc : "?"})`,
                        );
                        if (consoleOutEl)
                          consoleOutEl.textContent += `[job ${id}] END (rc=${typeof obj.rc !== "undefined" ? obj.rc : "?"})\n`;
                        // if diagnostics are present, show them in Problems pane
                        if (
                          Array.isArray(obj.diagnostics) &&
                          obj.diagnostics.length
                        ) {
                          try {
                            showDiagnostics(obj.diagnostics, obj.path || null);
                            // switch console panel to problems so user sees them
                            window.ferrufiShowConsolePanel &&
                              window.ferrufiShowConsolePanel("problems");
                          } catch (e) {
                            console.warn(
                              "failed to render diagnostics from SSE",
                              e,
                            );
                          }
                        }
                        break;
                      default:
                        appendKernel(
                          `[job ${id}] ${evt} ${JSON.stringify(obj)}`,
                        );
                        break;
                    }
                    // keep console scrolled
                    if (consoleOutEl)
                      consoleOutEl.scrollTop = consoleOutEl.scrollHeight;
                    return;
                  }
                } catch (e) {
                  console.warn("SSE job event handling error", e);
                }

                // Fallback: append any other message to kernel panel
                try {
                  appendKernel(JSON.stringify(obj));
                } catch (e) {}
              };

              es.onerror = (err) => {
                try {
                  appendKernel(
                    "[kernel-sse] connection error or closed, EventSource will retry automatically",
                  );
                  if (kernelStateEl)
                    kernelStateEl.textContent = "Kernel: disconnected";
                } catch (e) {}
              };

              // Provide a stop helper
              window.stopFerrufiKernelSSE = function () {
                try {
                  if (window._ferrufiKernelSSE) {
                    window._ferrufiKernelSSE.close();
                    window._ferrufiKernelSSE = null;
                    appendKernel("[kernel-sse] stopped by user");
                  }
                } catch (e) {}
              };
            } catch (e) {
              console.warn("initKernelSSE failed", e);
            }
          }

          // Start SSE connection lazily (immediately useful for UI)
          try {
            initKernelSSE();
          } catch (e) {
            console.warn("Kernel SSE init error", e);
          }
        } catch (e) {
          // non-fatal if the console panels aren't present
          console.warn("initConsoleTabs failed", e);
        }
      })();

      // Kernel restart
      if (restartKernelBtn) {
        restartKernelBtn.addEventListener("click", async () => {
          try {
            appendToConsole("Restarting kernel...");
            const r = await fetch("/api/kernel/restart", { method: "POST" });
            const j = await r.json();
            if (j && j.ok) appendToConsole("Kernel restarted.");
            else
              appendToConsole(
                `[error] Kernel restart failed: ${JSON.stringify(j)}`,
              );
          } catch (err) {
            appendToConsole(`[error] Kernel restart exception: ${String(err)}`);
          }
        });
      }
    } catch (e) {
      console.warn("IDE UI hooks init failed:", e && e.message ? e.message : e);
    }
  })();

  // Create a small API wrapper that proxies calls to the Bun server (/api/*).
  // It keeps the same surface (interpret, init, tryBind, setCurrentOutputTarget, _diagnostics)
  // so the rest of the UI doesn't need to change.
  function createApiWrapper(_M, helpers = {}) {
    const wrapper = {};
    let currentOutputTarget = null;

    // setCurrentOutputTarget is called by the UI to tell the wrapper where to
    // append runtime output (stdout/stderr) produced by the server response.
    wrapper.setCurrentOutputTarget =
      helpers.setCurrentOutputTarget ||
      function (target) {
        currentOutputTarget = target;
      };

    // Internal: call the server to interpret `code`. Optionally accepts { symbol } to
    // request a particular native export name (best-effort).
    async function callServerInterpret(code, options = {}) {
      const payload = { source: String(code || "") };
      if (options && options.symbol) payload.symbol = options.symbol;
      const res = await fetch("/api/interpret", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      if (!res.ok) {
        const txt = await res.text();
        throw new Error(`server interpret failed: ${res.status} ${txt}`);
      }
      const json = await res.json();
      return json;
    }

    // The public interpret function — returns the native return code (or null)
    wrapper.interpret = async function (code) {
      const outTarget = currentOutputTarget;
      try {
        const r = await callServerInterpret(code);
        const stdout = typeof r.stdout === "string" ? r.stdout : "";
        const stderr = typeof r.stderr === "string" ? r.stderr : "";
        // Append to output target if present
        try {
          if (outTarget && stdout)
            outTarget.append(stdout + (stdout.endsWith("\n") ? "" : "\n"));
          if (outTarget && stderr) outTarget.append(`[err] ${stderr}\n`);
        } catch (e) {
          // best-effort append; don't crash the interpreter call
          console.warn("append to output target failed", e);
        }
        // Render diagnostics (if present) into Problems pane
        try {
          if (r && Array.isArray(r.diagnostics) && r.diagnostics.length) {
            try {
              // `null` context: no explicit file path provided by this wrapper call
              showDiagnostics(r.diagnostics, null);
            } catch (e) {
              console.warn("rendering diagnostics failed", e);
            }
          }
        } catch (e) {
          // ignore diagnostics rendering errors
        }
        return typeof r.rc !== "undefined" ? r.rc : null;
      } catch (e) {
        if (outTarget) {
          try {
            outTarget.append(
              `[exception] ${e && e.message ? e.message : String(e)}\n`,
            );
          } catch (_) {}
        }
        throw e;
      }
    };

    // Synchronous tryBind: uses any cached candidates we may have
    wrapper.tryBind = function (names) {
      if (!names || names.length === 0) return null;
      wrapper._diagnostics = wrapper._diagnostics || {};
      const candidates = wrapper._diagnostics.candidates || [];
      for (const n of names) {
        if (candidates.includes(n) || candidates.includes("_" + n)) {
          wrapper._diagnostics.boundTo = n;
          const bound = function (code) {
            return wrapper.interpret(code, { symbol: n });
          };
          wrapper.interpret = bound;
          return bound;
        }
      }
      return null;
    };

    // Async tryBind: asks the server for exported symbols and binds to the first match.
    wrapper.tryBindAsync = async function (names) {
      if (!names || names.length === 0) return null;
      try {
        const res = await fetch("/api/inspect");
        if (!res.ok) return null;
        const js = await res.json();
        const symbols = Array.isArray(js.symbols) ? js.symbols : [];
        wrapper._diagnostics = wrapper._diagnostics || {};
        wrapper._diagnostics.candidates = symbols;
        for (const n of names) {
          if (symbols.includes(n) || symbols.includes("_" + n)) {
            wrapper._diagnostics.boundTo = n;
            const bound = function (code) {
              return wrapper.interpret(code, { symbol: n });
            };
            wrapper.interpret = bound;
            return bound;
          }
        }
      } catch (e) {
        // ignore and return null
      }
      return null;
    };

    // Provide a simple init that attempts to call a server init endpoint (server may ignore)
    wrapper.init = async function (a = 0, b = 0, c = 1) {
      try {
        await fetch("/api/init", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ a, b, c }),
        }).catch(() => {});
        return 0;
      } catch (e) {
        return -1;
      }
    };

    // Diagnostics
    wrapper._diagnostics = wrapper._diagnostics || {};
    wrapper._diagnostics.foundInterpret = true;
    wrapper._diagnostics.backend = "/api/interpret";

    return wrapper;
  }

  function makeCell(initialText = "") {
    const node = cellTemplate.content.cloneNode(true);
    const section = node.querySelector(".cell");

    // controls & DOM nodes
    const runBtn = section.querySelector(".run");
    const clearBtn = section.querySelector(".clear-output");
    const moveUpBtn = section.querySelector(".move-up");
    const moveDownBtn = section.querySelector(".move-down");
    const deleteBtn = section.querySelector(".delete");
    const editorHost = section.querySelector(".editor");
    const textarea = section.querySelector(".code"); // fallback textarea if CodeMirror is not available yet
    const output = section.querySelector(".output");
    const execSpans = section.querySelectorAll(".exec-count");
    const execPrompt = execSpans[0] || null;
    const execOut = execSpans[1] || null;
    let editor = null;

    // append helper
    output.append = function (txt) {
      this.textContent += txt;
      this.scrollTop = this.scrollHeight;
    };

    // initial text + fallback handler (textarea used if CodeMirror hasn't loaded)
    if (textarea) {
      textarea.value = initialText || "";
      textarea.style.display = "";
      textarea.addEventListener("keydown", (e) => {
        if (
          (e.key === "Enter" || e.keyCode === 13) &&
          (e.shiftKey || e.ctrlKey)
        ) {
          e.preventDefault();
          try {
            const start = textarea.selectionStart;
            const end = textarea.selectionEnd;
            const sel =
              typeof start === "number" &&
              typeof end === "number" &&
              end > start
                ? textarea.value.substring(start, end)
                : null;
            if (typeof section._run === "function") section._run(sel);
          } catch (err) {
            if (typeof section._run === "function") section._run();
          }
        }
      });
    }

    // Try to create a CodeMirror editor if available; if it fails we'll keep the textarea visible
    if (typeof window.createEditor === "function") {
      window
        .createEditor(editorHost, {
          value: initialText || "",
          language: "javascript",
          theme: document.body.getAttribute("data-theme"),
          onRun: (selection) => {
            if (typeof section._run === "function") section._run(selection);
          },
        })
        .then((ed) => {
          editor = ed;
          section._editor = editor;
          if (textarea) textarea.style.display = "none";
          // mark as editor-ready (useful for UI styling / tests)
          try {
            section.classList.add("editor-ready");
          } catch (e) {}
          // log for debugging
          try {
            console.log("CodeMirror editor created for cell", section);
          } catch (e) {}
          // notify the system that an editor was created (useful for UI updates)
          try {
            window.dispatchEvent(
              new CustomEvent("ferrufi:editor-created", {
                detail: { section },
              }),
            );
          } catch (e) {}
        })
        .catch((err) => {
          console.warn("createEditor failed", err);
          if (textarea) textarea.style.display = "";
        });
    } else {
      if (textarea) textarea.style.display = "";
    }

    // the actual runner for this cell; assigned to section._run for run-all
    async function runCell(selectionOverride) {
      // Visuals + counters
      output.textContent = "";
      output.append(`[running]\n`);
      section.classList.add("running");
      const execN = execCounter++;
      if (execPrompt) execPrompt.textContent = execN;
      if (execOut) execOut.textContent = execN;
      if (kernelStatus) kernelStatus.textContent = "Running…";

      let a = null;
      try {
        a = await initModule();
        a.setCurrentOutputTarget(output);

        if (typeof a.interpret !== "function") {
          output.append(
            `[error] interpreter function not found or not callable on module (type: ${typeof a.interpret})\n`,
          );
          try {
            const keys = Object.keys(moduleInstance).slice(0, 200).join(", ");
            const wkeys = moduleInstance.wasmExports
              ? Object.keys(moduleInstance.wasmExports).slice(0, 200).join(", ")
              : "";
            if (keys) output.append(`[debug] module keys: ${keys}\n`);
            if (wkeys) output.append(`[debug] wasm exports: ${wkeys}\n`);
            // If createApiWrapper recorded candidate names, show them as hints
            if (
              a &&
              a._diagnostics &&
              a._diagnostics.candidates &&
              a._diagnostics.candidates.length
            ) {
              output.append(
                `[debug] candidate export names: ${a._diagnostics.candidates.slice(0, 20).join(", ")}\n`,
              );
            }
            output.append(
              `[hint] Click 'Inspect Module' to view full exports (console + alert)\n`,
            );
            console.warn("[mufiz] interpreter not callable; wrapper:", a);
          } catch (e) {
            // ignore diagnostic failure
          }
          return;
        }

        // call interpret (synchronously or asynchronously). If the editor passed a selection, use it.
        const code =
          typeof selectionOverride !== "undefined" && selectionOverride !== null
            ? selectionOverride
            : editor && typeof editor.getValue === "function"
              ? editor.getValue()
              : textarea
                ? textarea.value
                : "";
        const res = await Promise.resolve(a.interpret(code));
        output.append(`\n[done] return code: ${res}\n`);
        return res;
      } catch (err) {
        output.append(
          `[exception] ${err && err.message ? err.message : String(err)}\n`,
        );
        console.error(err);
        throw err;
      } finally {
        try {
          if (a && a.setCurrentOutputTarget) a.setCurrentOutputTarget(null);
        } catch (_) {}
        if (kernelStatus) kernelStatus.textContent = "Idle";
        section.classList.remove("running");
      }
    }

    // wire UI
    runBtn.addEventListener("click", () => {
      // ensure _run exists and run
      section._run = runCell;
      // don't await here - leave it to runCell to manage the async
      runCell().catch((e) => {
        console.error("Cell run failed:", e);
      });
    });

    clearBtn.addEventListener("click", () => {
      output.textContent = "";
    });

    if (moveUpBtn) {
      moveUpBtn.addEventListener("click", () => {
        const prev = section.previousElementSibling;
        if (prev) notebook.insertBefore(section, prev);
      });
    }
    if (moveDownBtn) {
      moveDownBtn.addEventListener("click", () => {
        const next = section.nextElementSibling;
        if (next) notebook.insertBefore(next, section);
      });
    }
    if (deleteBtn) {
      deleteBtn.addEventListener("click", () => {
        if (confirm("Delete this cell?")) section.remove();
      });
    }

    // keep a reference so run-all can call it
    section._run = runCell;

    return section;
  }

  // UI actions (model-aware)
  addCellBtn.addEventListener("click", () => {
    const nc = { id: genId(), type: "code", source: "", outputs: [] };
    notebookModel.push(nc);
    saveNotebook();
    renderNotebook();
    // focus the newly added cell's editor or fallback textarea
    setTimeout(() => {
      const el = document.querySelector(`.cell[data-cell-id="${nc.id}"]`);
      if (el) {
        if (el._editor && typeof el._editor.focus === "function")
          el._editor.focus();
        else el.querySelector("textarea.code")?.focus();
      }
    }, 150);
  });

  // Add Markdown button handler (insert markdown cell and open for editing)
  const addMarkdownBtn = document.getElementById("add-markdown");
  if (addMarkdownBtn) {
    addMarkdownBtn.addEventListener("click", () => {
      const nc = {
        id: genId(),
        type: "markdown",
        source: "# New Markdown",
        outputs: [],
      };
      notebookModel.push(nc);
      saveNotebook();
      renderNotebook();
      setTimeout(() => {
        const el = document.querySelector(`.cell[data-cell-id="${nc.id}"]`);
        if (el) {
          const prev = el.querySelector(".preview-toggle");
          if (prev && prev.classList.contains("active")) prev.click();
          const ed = el._editor;
          if (ed && typeof ed.focus === "function") ed.focus();
          else el.querySelector("textarea.code")?.focus();
        }
      }, 120);
    });
  }

  // Bind interpreter name button (lets you try alternate export names at runtime)
  const bindInterpBtn = document.getElementById("bind-interp");
  if (bindInterpBtn) {
    bindInterpBtn.addEventListener("click", async () => {
      const nameInput = document.getElementById("interp-name");
      const name = nameInput ? nameInput.value.trim() : "";
      if (!name) {
        showInfo("Enter interpreter name");
        return;
      }
      try {
        const apiObj = await initModule();
        let bound = null;
        // Try a quick synchronous bind if candidates are cached
        if (apiObj && typeof apiObj.tryBind === "function") {
          bound = apiObj.tryBind([name]);
        }
        // Try an async bind that queries the server's symbols
        if (!bound && apiObj && typeof apiObj.tryBindAsync === "function") {
          bound = await apiObj.tryBindAsync([name]);
        }
        // Try common name variations (async)
        if (!bound && apiObj && typeof apiObj.tryBindAsync === "function") {
          const guesses = [
            name,
            "_" + name,
            "mufiz_" + name,
            name + "_utf8",
            "interpret",
          ];
          bound = await apiObj.tryBindAsync(guesses);
        }
        if (bound && typeof bound === "function") {
          apiObj.interpret = bound;
          apiObj._diagnostics = apiObj._diagnostics || {};
          apiObj._diagnostics.boundTo = name;
          showInfo("Bound interpreter to " + name);
          console.info("[mufiz] bound interpreter to", name);
        } else {
          showInfo(
            "Could not bind interpreter to " +
              name +
              ". Try Inspect Module to see exported symbols.",
          );
          console.warn(
            "bind failed; diagnostics:",
            apiObj && apiObj._diagnostics,
            apiObj,
          );
        }
      } catch (err) {
        console.error("bind handler error:", err);
        showInfo("Bind failed (see console).");
      }
    });
  }

  // Run all cells sequentially (model-aware)
  if (runAllBtn) {
    runAllBtn.addEventListener("click", async () => {
      if (kernelStatus) kernelStatus.textContent = "Running...";
      for (const cell of notebookModel) {
        if (cell.type === "code") {
          try {
            await runCellById(cell.id);
          } catch (err) {
            console.error("run-all: cell failed", err);
          }
        }
      }
      if (kernelStatus) kernelStatus.textContent = "Idle";
    });
  }

  const inspectBtn = document.getElementById("inspect-module");
  if (inspectBtn) {
    inspectBtn.addEventListener("click", async () => {
      try {
        const res = await fetch("/api/inspect");
        const json = await res.json();
        console.log("[mufiz] inspect:", json);
        let content = "";
        if (Array.isArray(json.symbols)) {
          content = json.symbols.join("\n");
        } else if (json.raw) {
          content = json.raw;
        } else {
          content = JSON.stringify(json, null, 2);
        }
        alert(`mufiz native symbols:\n${content}`);
      } catch (err) {
        console.error("inspect failed", err);
        alert("Inspect failed (see console).");
      }
    });
  }

  // Notebook model / persistence / rendering helpers
  let notebookModel = [];

  function genId() {
    return (
      "c_" +
      Date.now().toString(36).slice(-6) +
      "_" +
      Math.random().toString(36).slice(2, 6)
    );
  }

  /* -----------------------------
     File manager (workspace files)
     Stores files in localStorage under key FILES_KEY
  ----------------------------- */
  const FILES_KEY = "ferrufi_files_v1";
  let files = []; // { name, content, createdAt, modifiedAt }
  const openTabs = new Map(); // name -> { container, editor, unsaved }

  function defaultFileTemplate() {
    return '// Example mufiz code\nprint("hello from mufiz")\n\nvar a = 5;\nprint a;\n';
  }

  function loadFiles() {
    // Synchronous fallback behavior: return any cached files from localStorage immediately so the UI can render.
    // In parallel, attempt to load workspace files from the server endpoints and update the UI when available.
    try {
      // Fire-and-forget attempt to load from server workspace API. If it succeeds we replace `files` and rerender.
      (async () => {
        try {
          const listRes = await fetch("/api/workspace/list?path=.");
          if (!listRes.ok) throw new Error("workspace list not available");
          const listJson = await listRes.json();
          if (!listJson || !Array.isArray(listJson.files)) return;
          // Fetch contents for non-directory entries (limit to avoid heavy work)
          const entries = listJson.files
            .filter((f) => !f.isDirectory)
            .slice(0, 100);
          const filePromises = entries.map(async (ent) => {
            try {
              const r = await fetch(
                `/api/workspace/read?path=${encodeURIComponent(ent.path)}`,
              );
              if (!r.ok) return null;
              const j = await r.json();
              return {
                name: ent.name,
                content: j && typeof j.content === "string" ? j.content : "",
                createdAt: ent.mtime || Date.now(),
                modifiedAt: ent.mtime || Date.now(),
              };
            } catch (e) {
              return null;
            }
          });
          const results = (await Promise.all(filePromises)).filter(Boolean);
          if (results.length) {
            files = results;
            // persist cache to localStorage for offline fallback
            try {
              localStorage.setItem(FILES_KEY, JSON.stringify(files));
            } catch (e) {
              // ignore storage errors
            }
            // update UI
            try {
              renderFileList();
            } catch (e) {}
          }
        } catch (e) {
          // server not available or request failed; keep local cache
        }
      })();
      // LocalStorage-based immediate return for synchronous callers
      const raw = localStorage.getItem(FILES_KEY);
      if (!raw) {
        // initialize with a default file
        files = [
          {
            name: "main.muf",
            content: defaultFileTemplate(),
            createdAt: Date.now(),
            modifiedAt: Date.now(),
          },
        ];
        saveFiles();
        return files;
      }
      files = JSON.parse(raw);
      if (!Array.isArray(files)) files = [];
      return files;
    } catch (e) {
      console.warn("loadFiles failed", e);
      files = [];
      return files;
    }
  }

  function saveFiles() {
    // Always persist a local cache so UI works offline or if server is unavailable.
    try {
      localStorage.setItem(FILES_KEY, JSON.stringify(files));
    } catch (e) {
      console.warn("saveFiles failed", e);
    }
    // Do not perform a bulk server write here because the server API currently exposes per-file write.
    // Individual saves are handled by `saveCurrentFile` which attempts a server write then falls back to localStorage.
  }

  function createFile(name, content) {
    if (!name || typeof name !== "string") throw new Error("invalid name");
    if (files.find((f) => f.name === name)) throw new Error("file exists");
    const f = {
      name,
      content: content || "",
      createdAt: Date.now(),
      modifiedAt: Date.now(),
    };
    files.unshift(f);
    // persist locally immediately
    saveFiles();
    renderFileList();
    // Try to create/write file on server workspace as well. If server is unavailable, ignore and keep local-only.
    (async () => {
      try {
        await fetch("/api/workspace/write", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ path: name, content: f.content }),
        });
      } catch (e) {
        // ignore server errors - file remains in local cache
      }
    })();
    return f;
  }

  async function deleteFile(name) {
    if (!name) return;
    // Try server-side delete first, fall back to local-only deletion if server unavailable.
    try {
      const res = await fetch("/api/workspace/delete", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ path: name, force: false }),
      });
      if (!res.ok) {
        const txt = await res.text().catch(() => "");
        throw new Error(`server delete failed: ${res.status} ${txt}`);
      }
      const js = await res.json().catch(() => ({}));
      if (js && js.ok === false) {
        // If server explicitly rejects, surface reason but continue to attempt local cleanup
        appendToConsole(`[warn] server delete: ${js.error || "rejected"}`);
      }
    } catch (e) {
      // server delete failed - emit a warning but proceed to remove local cached file so UI stays consistent
      appendToConsole(
        `[warn] delete fallback (server error): ${e && e.message ? e.message : String(e)}`,
      );
    }

    // Remove from local cache
    files = files.filter((f) => f.name !== name);
    saveFiles();

    // close tab if open
    if (openTabs.has(name)) {
      const t = openTabs.get(name);
      try {
        if (t.editor && typeof t.editor.destroy === "function")
          t.editor.destroy();
      } catch (e) {}
      try {
        if (t.container && t.container.remove) t.container.remove();
      } catch (e) {}
      openTabs.delete(name);
      renderTabs();
    }
    renderFileList();
  }

  async function renameFile(oldName, newName) {
    // Try server-side rename first, fall back to local-only rename on error.
    if (!oldName || !newName || oldName === newName) {
      throw new Error("invalid names");
    }
    if (files.find((f) => f.name === newName)) {
      throw new Error("target exists");
    }

    // Attempt server rename
    try {
      const res = await fetch("/api/workspace/rename", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ oldPath: oldName, newPath: newName }),
      });
      if (!res.ok) {
        const txt = await res.text().catch(() => "");
        throw new Error(`server rename failed: ${res.status} ${txt}`);
      }
      const js = await res.json().catch(() => ({}));
      if (!js || js.ok === false) {
        throw new Error(js && js.error ? js.error : "server rename rejected");
      }
      // Server succeeded: update local cache and UI
      const f = files.find((f) => f.name === oldName);
      if (f) {
        f.name = newName;
        f.modifiedAt = Date.now();
      }
    } catch (e) {
      // Server-side rename failed; attempt local rename (best-effort)
      const f = files.find((f) => f.name === oldName);
      if (!f)
        throw new Error(
          "not found and server rename failed: " +
            (e && e.message ? e.message : String(e)),
        );
      f.name = newName;
      f.modifiedAt = Date.now();
      // keep local-only copy; inform user via console
      appendToConsole(
        `[warn] rename fallback: ${e && e.message ? e.message : String(e)}`,
      );
    }

    // Update open tabs if any
    if (openTabs.has(oldName)) {
      const t = openTabs.get(oldName);
      openTabs.delete(oldName);
      openTabs.set(newName, t);
      try {
        t.container.dataset.name = newName;
      } catch (e) {}
    }

    saveFiles();
    renderFileList();
    renderTabs();
  }

  // Render file list as a simple directory tree. Supports nested paths returned by server (file.path).
  // Provides right-click context menu for Rename/Delete and click to open files.
  function renderFileList() {
    if (!fileListEl) return;
    fileListEl.innerHTML = "";

    // If we have no files, show placeholder
    if (!files || files.length === 0) {
      const empty = document.createElement("div");
      empty.className = "file-placeholder";
      empty.textContent = "No files yet — create one with New File or Upload";
      fileListEl.appendChild(empty);
      return;
    }

    // Build a tree structure from files entries. Server entries may include `path` (relative) or just `name`.
    const tree = {};
    for (const f of files) {
      const rel = (f.path && f.path.replace(/^\/+/, "")) || f.name || "";
      const parts = rel.split("/").filter(Boolean);
      let node = tree;
      for (let i = 0; i < parts.length; i++) {
        const p = parts[i];
        if (!node[p])
          node[p] = { __children: {}, __meta: null, __isDir: false };
        if (i === parts.length - 1) {
          // leaf (file) — mark meta
          node[p].__meta = {
            name: p,
            path: rel,
            size: f.size || 0,
            mtime: f.mtime || f.modifiedAt || Date.now(),
          };
          node[p].__isDir = false;
        } else {
          // interior directory
          node[p].__isDir = true;
        }
        node = node[p].__children;
      }
    }

    // Helper to create folder DOM node with toggle
    function makeFolder(name, nodeObj, parentPath) {
      const folderEl = document.createElement("div");
      folderEl.className = "file-folder";
      const header = document.createElement("div");
      header.className = "file-folder-header";
      header.textContent = name;
      header.tabIndex = 0;
      header.addEventListener("click", () => {
        listEl.classList.toggle("collapsed");
      });
      header.addEventListener("contextmenu", (ev) => {
        ev.preventDefault();
        showContextMenu(ev.pageX, ev.pageY, {
          type: "dir",
          name,
          path: parentPath ? `${parentPath}/${name}` : name,
        });
      });
      folderEl.appendChild(header);
      const listEl = document.createElement("div");
      listEl.className = "file-folder-children";
      folderEl.appendChild(listEl);

      // recursively render children
      const children = nodeObj.__children || {};
      const keys = Object.keys(children).sort((a, b) => {
        const A = children[a].__isDir ? "0" + a : "1" + a;
        const B = children[b].__isDir ? "0" + b : "1" + b;
        return A.localeCompare(B);
      });
      for (const k of keys) {
        const child = children[k];
        if (child.__isDir) {
          listEl.appendChild(
            makeFolder(k, child, parentPath ? `${parentPath}/${name}` : name),
          );
        } else {
          listEl.appendChild(makeFileEntry(child.__meta));
        }
      }
      return folderEl;
    }

    // File entry builder
    function makeFileEntry(meta) {
      const el = document.createElement("div");
      el.className = "file-item";
      el.textContent = meta.name;
      el.title = meta.path;
      el.addEventListener("click", () => {
        openFile(meta.path || meta.name);
      });
      el.addEventListener("contextmenu", (ev) => {
        ev.preventDefault();
        showContextMenu(ev.pageX, ev.pageY, {
          type: "file",
          name: meta.name,
          path: meta.path,
        });
      });
      const metaDiv = document.createElement("div");
      metaDiv.className = "file-meta";
      try {
        metaDiv.textContent = new Date(meta.mtime).toLocaleString();
      } catch (e) {
        metaDiv.textContent = "";
      }
      el.appendChild(metaDiv);
      return el;
    }

    // Build top-level nodes
    const topKeys = Object.keys(tree).sort();
    for (const k of topKeys) {
      const n = tree[k];
      if (n.__isDir) {
        fileListEl.appendChild(makeFolder(k, n, ""));
      } else if (n.__meta) {
        fileListEl.appendChild(makeFileEntry(n.__meta));
      } else {
        // If node has children but not marked dir, attempt to render children
        const wrapper = document.createElement("div");
        wrapper.className = "file-group";
        const header = document.createElement("div");
        header.className = "file-group-header";
        header.textContent = k;
        wrapper.appendChild(header);
        const children = n.__children || {};
        for (const ck of Object.keys(children)) {
          const child = children[ck];
          if (child.__isDir) wrapper.appendChild(makeFolder(ck, child, k));
          else if (child.__meta)
            wrapper.appendChild(makeFileEntry(child.__meta));
        }
        fileListEl.appendChild(wrapper);
      }
    }

    // Context menu helper
    let activeContextMenu = null;
    function hideContextMenu() {
      if (!activeContextMenu) return;
      try {
        activeContextMenu.remove();
      } catch (e) {}
      activeContextMenu = null;
    }
    document.addEventListener("click", hideContextMenu);

    function showContextMenu(x, y, info) {
      hideContextMenu();
      const menu = document.createElement("div");
      menu.className = "file-context-menu";
      menu.style.position = "absolute";
      menu.style.left = x + "px";
      menu.style.top = y + "px";
      menu.style.zIndex = 9999;
      const rename = document.createElement("div");
      rename.className = "cm-item";
      rename.textContent = "Rename";
      rename.addEventListener("click", async () => {
        hideContextMenu();
        const targetName = prompt("New name:", info.name);
        if (!targetName) return;
        try {
          if (info.type === "file") {
            await renameFile(info.path, targetName);
            appendToConsole(`Renamed ${info.path} -> ${targetName}`);
          } else {
            await renameFile(info.path, targetName);
            appendToConsole(`Renamed ${info.path} -> ${targetName}`);
          }
        } catch (e) {
          appendToConsole(
            `[error] rename failed: ${e && e.message ? e.message : e}`,
          );
        }
        loadFiles();
      });
      menu.appendChild(rename);

      const del = document.createElement("div");
      del.className = "cm-item";
      del.textContent = "Delete";
      del.addEventListener("click", async () => {
        hideContextMenu();
        if (!confirm(`Delete ${info.path || info.name}?`)) return;
        try {
          await deleteFile(info.path || info.name);
          appendToConsole(`Deleted ${info.path || info.name}`);
        } catch (e) {
          appendToConsole(
            `[error] delete failed: ${e && e.message ? e.message : e}`,
          );
        }
        loadFiles();
      });
      menu.appendChild(del);

      activeContextMenu = menu;
      document.body.appendChild(menu);
    }
  }

  function renderTabs() {
    if (!fileTabsEl) return;
    fileTabsEl.innerHTML = "";
    for (const [name, data] of openTabs) {
      const btn = document.createElement("button");
      btn.className = "file-tab";
      btn.textContent = name + (data.unsaved ? " *" : "");
      btn.addEventListener("click", () => {
        setActiveTab(name);
      });
      const closeBtn = document.createElement("span");
      closeBtn.textContent = " ×";
      closeBtn.style.marginLeft = "6px";
      closeBtn.addEventListener("click", (ev) => {
        ev.stopPropagation();
        closeTab(name);
      });
      btn.appendChild(closeBtn);
      fileTabsEl.appendChild(btn);
    }
  }

  function setActiveTab(name) {
    for (const [k, d] of openTabs) {
      d.container.style.display = k === name ? "" : "none";
    }
    renderTabs();
  }

  function closeTab(name) {
    const t = openTabs.get(name);
    if (!t) return;
    try {
      t.editor.destroy();
    } catch (e) {}
    try {
      t.container.remove();
    } catch (e) {}
    openTabs.delete(name);
    renderTabs();
  }

  async function openFile(name) {
    // Attempt to read file from server workspace API first. If it fails, fall back to local cache.
    let f = files.find((x) => x.name === name);
    try {
      const r = await fetch(
        `/api/workspace/read?path=${encodeURIComponent(name)}`,
      );
      if (r.ok) {
        const js = await r.json();
        f = {
          name: name,
          content: js && typeof js.content === "string" ? js.content : "",
        };
        // update local cache with server content (best-effort)
        try {
          const idx = files.findIndex((x) => x.name === name);
          if (idx !== -1) {
            files[idx].content = f.content;
            files[idx].modifiedAt = Date.now();
          } else {
            files.unshift({
              name,
              content: f.content,
              createdAt: Date.now(),
              modifiedAt: Date.now(),
            });
          }
          saveFiles();
          renderFileList();
        } catch (e) {
          // ignore cache update errors
        }
      }
    } catch (e) {
      // unable to contact server, continue with local cache
    }
    if (!f) return;
    // if already open, focus its tab
    if (openTabs.has(name)) {
      setActiveTab(name);
      return;
    }
    // create a container for this tab
    const cont = document.createElement("div");
    cont.className = "file-tab-content";
    cont.dataset.name = name;
    cont.style.display = "none";
    fileEditorEl.appendChild(cont);

    // create CM editor for this file
    try {
      const ed = await createEditor(cont, {
        value: f.content,
        language: "javascript",
        theme: document.body.getAttribute("data-theme"),
        onChange: (v) => {
          f.content = v;
          const tab = openTabs.get(name);
          if (tab) tab.unsaved = true;
          renderTabs();
        },
        onRun: (selection) => {
          // run selection or whole file
          const code =
            selection && selection.length
              ? selection
              : openTabs.get(name).editor && openTabs.get(name).editor.getValue
                ? openTabs.get(name).editor.getValue()
                : f.content;
          appendToConsole(`--- Running ${name} ---`);
          // Use server run
          fetch("/api/interpret", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ source: code }),
          })
            .then((r) => r.json())
            .then((js) => {
              if (js.stdout) appendToConsole(js.stdout);
              if (js.stderr) appendToConsole(`[stderr] ${js.stderr}`);
              appendToConsole(`--- done (rc=${js.rc}) ---`);
            })
            .catch((e) => appendToConsole(`[error] ${String(e)}`));
        },
      });
      openTabs.set(name, { container: cont, editor: ed, unsaved: false });
      renderTabs();
      setActiveTab(name);
    } catch (e) {
      console.error("openFile createEditor failed", e);
      cont.remove();
    }
  }

  function getActiveTabName() {
    for (const [k, d] of openTabs) {
      if (d.container && d.container.style.display !== "none") return k;
    }
    return null;
  }

  function saveCurrentFile() {
    const name = getActiveTabName();
    if (!name) return;
    const t = openTabs.get(name);
    const content =
      t && t.editor && t.editor.getValue ? t.editor.getValue() : "";
    const f = files.find((x) => x.name === name);
    if (f) {
      f.content = content;
      f.modifiedAt = Date.now();
      // Update local cache immediately
      saveFiles();
      // Attempt to save to server workspace; fall back to local-only if server fails.
      (async () => {
        try {
          const res = await fetch("/api/workspace/write", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ path: name, content: content }),
          });
          if (!res.ok) {
            // server rejected write; keep local copy
            console.warn("workspace write failed", await res.text());
          }
        } catch (e) {
          // network/server error: keep local cache
          console.warn("workspace write error", e);
        } finally {
          // Update UI state regardless
          t.unsaved = false;
          renderTabs();
          renderFileList();
        }
      })();
    }
  }

  function runCurrentFile() {
    const name = getActiveTabName();
    if (!name) return;
    const t = openTabs.get(name);
    const code = t && t.editor && t.editor.getValue ? t.editor.getValue() : "";
    appendToConsole(`--- Running ${name} ---`);
    fetch("/api/interpret", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ source: code }),
    })
      .then((r) => r.json())
      .then((js) => {
        if (js.stdout) appendToConsole(js.stdout);
        if (js.stderr) appendToConsole(`[stderr] ${js.stderr}`);
        appendToConsole(`--- done (rc=${js.rc}) ---`);
      })
      .catch((e) => appendToConsole(`[error] ${String(e)}`));
  }

  function appendToConsole(txt) {
    try {
      const el = document.getElementById("console-output");
      if (!el) return;
      el.textContent += String(txt) + "\n";
      el.scrollTop = el.scrollHeight;
    } catch (e) {
      // ignore
    }
  }
  // Problems pane helpers
  function clearProblems() {
    try {
      const p = document.getElementById("problems-list");
      if (!p) return;
      p.innerHTML = "";
    } catch (e) {
      console.warn("clearProblems failed", e);
    }
  }
  function showDiagnostics(diagnostics, contextPath) {
    // diagnostics: [{ id, severity, message, line?, col?, path? }, ...]
    try {
      const p = document.getElementById("problems-list");
      if (!p) return;
      p.innerHTML = "";
      for (const d of diagnostics) {
        const row = document.createElement("div");
        row.className = "problem";
        const sev = d.severity || "error";
        const msg = d.message || JSON.stringify(d);
        const lineInfo =
          typeof d.line !== "undefined"
            ? ` (Ln ${d.line}${typeof d.col !== "undefined" ? `, Col ${d.col}` : ""})`
            : "";
        const pathHint = d.path
          ? ` ${d.path}`
          : contextPath
            ? ` ${contextPath}`
            : "";
        row.textContent = `${sev.toUpperCase()}: ${msg}${lineInfo}${pathHint}`;
        // clickable: attempt to open file and navigate to line if possible
        row.style.cursor = "pointer";
        row.addEventListener("click", async () => {
          try {
            const targetPath = d.path || contextPath || null;
            if (targetPath) {
              await openFile(targetPath);
              // try to focus editor and reveal line
              setTimeout(() => {
                const tab = openTabs.get(targetPath);
                if (!tab) return;
                const ed = tab.editor;
                if (!ed) return;
                // If editor exposes a CodeMirror view, attempt to set selection at line
                try {
                  if (
                    ed.view &&
                    typeof ed.view.dispatch === "function" &&
                    typeof d.line !== "undefined"
                  ) {
                    const docText = ed.view.state.doc.toString();
                    const lines = docText.split("\n");
                    // compute offset for start of line (1-based line numbers expected)
                    const lineNum = Math.max(1, Number(d.line) || 1);
                    let offset = 0;
                    for (let i = 0; i < lineNum - 1 && i < lines.length; i++) {
                      offset += lines[i].length + 1;
                    }
                    ed.view.focus();
                    try {
                      ed.view.dispatch({
                        selection: { anchor: offset, head: offset },
                        scrollIntoView: true,
                      });
                    } catch (e) {
                      // older Editor API variant
                      try {
                        ed.view.focus();
                      } catch (_) {}
                    }
                  } else if (ed.focus) {
                    ed.focus();
                  }
                } catch (e) {
                  // best-effort
                }
              }, 60);
            }
          } catch (e) {
            console.warn("problem click handler failed", e);
          }
        });
        p.appendChild(row);
      }
    } catch (e) {
      console.warn("showDiagnostics failed", e);
    } finally {
      try {
        // also surface count in console tab
        const pEl = document.getElementById("problems-list");
        const count = pEl ? pEl.children.length : 0;
        if (count > 0) {
          appendToConsole(`[problems] ${count} issue(s)`);
        }
      } catch (e) {}
    }
  }

  // Ensure explorer is visible if files exist
  try {
    renderFileList();
  } catch (e) {}

  function saveNotebook() {
    try {
      localStorage.setItem(
        "ferrufi_notebook_v1",
        JSON.stringify(notebookModel),
      );
    } catch (e) {
      console.warn("saveNotebook failed", e);
    }
  }

  function loadNotebook() {
    try {
      const raw = localStorage.getItem("ferrufi_notebook_v1");
      if (raw) {
        notebookModel = JSON.parse(raw);
        return notebookModel;
      }
    } catch (e) {
      console.warn("loadNotebook error", e);
    }
    notebookModel = defaultNotebook();
    saveNotebook();
    return notebookModel;
  }

  function defaultNotebook() {
    return [
      {
        id: genId(),
        type: "markdown",
        source:
          "# Ferrufi Notebook\\nThis is a simple notebook — mix markdown and executable code cells.",
        outputs: [],
      },
      {
        id: genId(),
        type: "code",
        source: '// Example mufiz code\\nprint(\"hello from mufiz\")',
        outputs: [],
      },
    ];
  }

  async function runCellById(cellId, selection = null) {
    const cell = notebookModel.find((c) => c.id === cellId);
    if (!cell) return;
    if (cell.type !== "code") {
      // For markdown cells, run toggles preview (handled by UI). Nothing to execute here.
      return;
    }
    // find DOM for cell
    const section = document.querySelector(`.cell[data-cell-id="${cellId}"]`);
    if (!section) return;
    const outputEl = section.querySelector(".output");
    outputEl.textContent = "";
    outputEl.append("[running]\n");
    kernelStatus && (kernelStatus.textContent = "Running...");
    let a = null;
    try {
      a = await initModule();
      a.setCurrentOutputTarget(outputEl);
      const codeToRun =
        typeof selection === "string" && selection.length
          ? selection
          : cell.source;
      const res = await Promise.resolve(a.interpret(codeToRun));
      // store captured output text
      cell.outputs = [outputEl.textContent];
      saveNotebook();
      outputEl.append(`\n[done] return code: ${res}\n`);
      return res;
    } catch (e) {
      outputEl.append(
        `[exception] ${e && e.message ? e.message : String(e)}\n`,
      );
      console.error(e);
      throw e;
    } finally {
      try {
        if (a && a.setCurrentOutputTarget) a.setCurrentOutputTarget(null);
      } catch (e) {}
      kernelStatus && (kernelStatus.textContent = "Idle");
    }
  }

  function createCellElement(cell) {
    const node = cellTemplate.content.cloneNode(true);
    const section = node.querySelector(".cell");
    section.setAttribute("data-cell-id", cell.id);

    const runBtn = section.querySelector(".run");
    const clearBtn = section.querySelector(".clear-output");
    const moveUpBtn = section.querySelector(".move-up");
    const moveDownBtn = section.querySelector(".move-down");
    const deleteBtn = section.querySelector(".delete");
    const typeSelect = section.querySelector(".cell-type");
    const previewToggle = section.querySelector(".preview-toggle");
    const mdPreview = section.querySelector(".cell-markdown-preview");
    const editorHost = section.querySelector(".editor");
    const fbTextarea = section.querySelector("textarea.code");
    const output = section.querySelector(".output");
    const execSpans = section.querySelectorAll(".exec-count");

    // initialize UI
    if (execSpans[0]) execSpans[0].textContent = "";
    if (execSpans[1]) execSpans[1].textContent = "";
    if (typeSelect) typeSelect.value = cell.type || "code";
    if (cell.outputs && cell.outputs.length)
      output.textContent = cell.outputs.join("\\n");

    // fallback textarea binding
    if (fbTextarea) {
      fbTextarea.value = cell.source || "";
      fbTextarea.addEventListener("input", (e) => {
        cell.source = e.target.value;
        saveNotebook();
      });
    }

    let localEditor = null;

    // create editor instance (async) and wire onChange -> model
    if (typeof window.createEditor === "function") {
      window
        .createEditor(editorHost, {
          value: cell.source || "",
          language: cell.type === "markdown" ? "markdown" : "javascript",
          theme: document.body.getAttribute("data-theme"),
          onRun: (selection) => {
            runCellById(cell.id, selection);
          },
          onChange: (v) => {
            cell.source = v;
            saveNotebook();
          },
        })
        .then((ed) => {
          localEditor = ed;
          section._editor = ed;
          if (fbTextarea) fbTextarea.style.display = "none";
          // If cell.type is markdown, initially show rendered preview
          if (cell.type === "markdown") {
            try {
              const md =
                typeof marked !== "undefined"
                  ? marked.parse(cell.source || "")
                  : "<pre>" +
                    (cell.source || "").replace(/</g, "&lt;") +
                    "</pre>";
              const sanitized =
                typeof DOMPurify !== "undefined" ? DOMPurify.sanitize(md) : md;
              mdPreview.innerHTML = sanitized;
              mdPreview.style.display = "block";
              if (ed.view && ed.view.dom) ed.view.dom.style.display = "none";
              if (previewToggle) previewToggle.classList.add("active");
            } catch (e) {
              /* ignore render errors */
            }
          }
          try {
            window.dispatchEvent(
              new CustomEvent("ferrufi:editor-created", {
                detail: { section },
              }),
            );
          } catch (e) {}
        })
        .catch((err) => {
          console.warn("createEditor failed for cell", cell.id, err);
          if (fbTextarea) fbTextarea.style.display = "";
        });
    } else {
      if (fbTextarea) fbTextarea.style.display = "";
    }

    // preview toggle
    if (previewToggle) {
      previewToggle.addEventListener("click", () => {
        if (previewToggle.classList.contains("active")) {
          // switch to edit
          previewToggle.classList.remove("active");
          mdPreview.style.display = "none";
          if (
            section._editor &&
            section._editor.view &&
            section._editor.view.dom
          )
            section._editor.view.dom.style.display = "";
          if (fbTextarea) fbTextarea.style.display = "none";
        } else {
          // switch to preview
          previewToggle.classList.add("active");
          const content =
            section._editor && typeof section._editor.getValue === "function"
              ? section._editor.getValue()
              : fbTextarea
                ? fbTextarea.value
                : "";
          let html = "";
          try {
            html =
              typeof marked !== "undefined"
                ? marked.parse(content)
                : "<pre>" + content.replace(/</g, "&lt;") + "</pre>";
          } catch (e) {
            html = "<pre>" + content.replace(/</g, "&lt;") + "</pre>";
          }
          if (typeof DOMPurify !== "undefined") html = DOMPurify.sanitize(html);
          mdPreview.innerHTML = html;
          mdPreview.style.display = "block";
          if (
            section._editor &&
            section._editor.view &&
            section._editor.view.dom
          )
            section._editor.view.dom.style.display = "none";
          if (fbTextarea) fbTextarea.style.display = "none";
        }
      });
      // hide preview button for code cells
      if (cell.type !== "markdown") previewToggle.style.display = "none";
    }

    // type selector change
    if (typeSelect) {
      typeSelect.addEventListener("change", async (e) => {
        const newType = e.target.value;
        cell.type = newType;
        saveNotebook();
        // re-create editor with appropriate language
        try {
          // preserve content
          const content =
            section._editor && typeof section._editor.getValue === "function"
              ? section._editor.getValue()
              : fbTextarea
                ? fbTextarea.value
                : "";
          if (
            section._editor &&
            typeof section._editor.destroy === "function"
          ) {
            try {
              section._editor.destroy();
            } catch (e) {}
            section._editor = null;
          }
          if (typeof window.createEditor === "function") {
            const ed = await window.createEditor(editorHost, {
              value: content,
              language: newType === "markdown" ? "markdown" : "javascript",
              theme: document.body.getAttribute("data-theme"),
              onRun: (selection) => {
                runCellById(cell.id, selection);
              },
              onChange: (v) => {
                cell.source = v;
                saveNotebook();
              },
            });
            section._editor = ed;
            if (fbTextarea) fbTextarea.style.display = "none";
          } else {
            if (fbTextarea) {
              fbTextarea.style.display = "";
              fbTextarea.value = content;
            }
          }
          if (newType === "markdown") {
            // show preview by default
            const content2 =
              section._editor && typeof section._editor.getValue === "function"
                ? section._editor.getValue()
                : fbTextarea
                  ? fbTextarea.value
                  : "";
            let html = "";
            try {
              html =
                typeof marked !== "undefined"
                  ? marked.parse(content2)
                  : "<pre>" + content2.replace(/</g, "&lt;") + "</pre>";
            } catch (e) {
              html = "<pre>" + content2.replace(/</g, "&lt;") + "</pre>";
            }
            if (typeof DOMPurify !== "undefined")
              html = DOMPurify.sanitize(html);
            mdPreview.innerHTML = html;
            mdPreview.style.display = "block";
            if (
              section._editor &&
              section._editor.view &&
              section._editor.view.dom
            )
              section._editor.view.dom.style.display = "none";
            if (previewToggle) previewToggle.classList.add("active");
            previewToggle.style.display = "";
          } else {
            if (previewToggle) {
              previewToggle.classList.remove("active");
              previewToggle.style.display = "none";
            }
            if (mdPreview) mdPreview.style.display = "none";
            if (
              section._editor &&
              section._editor.view &&
              section._editor.view.dom
            )
              section._editor.view.dom.style.display = "";
          }
        } catch (err) {
          console.warn("Failed to change cell type", err);
        }
      });
    }

    // run button: behave differently for code vs markdown
    runBtn.addEventListener("click", async () => {
      if (cell.type === "markdown") {
        // toggle preview on run
        if (previewToggle && !previewToggle.classList.contains("active"))
          previewToggle.click();
        else {
          // re-render
          if (previewToggle && previewToggle.classList.contains("active"))
            (previewToggle.click(), previewToggle.click());
        }
        return;
      }
      // code cell: execute
      try {
        await runCellById(cell.id, section);
      } catch (err) {}
    });

    clearBtn.addEventListener("click", () => {
      cell.outputs = [];
      output.textContent = "";
      saveNotebook();
    });

    if (moveUpBtn) {
      moveUpBtn.addEventListener("click", () => {
        const idx = notebookModel.findIndex((c) => c.id === cell.id);
        if (idx > 0) {
          const a = notebookModel.splice(idx, 1)[0];
          notebookModel.splice(idx - 1, 0, a);
          saveNotebook();
          renderNotebook();
        }
      });
    }
    if (moveDownBtn) {
      moveDownBtn.addEventListener("click", () => {
        const idx = notebookModel.findIndex((c) => c.id === cell.id);
        if (idx >= 0 && idx < notebookModel.length - 1) {
          const a = notebookModel.splice(idx, 1)[0];
          notebookModel.splice(idx + 1, 0, a);
          saveNotebook();
          renderNotebook();
        }
      });
    }
    if (deleteBtn) {
      deleteBtn.addEventListener("click", () => {
        if (confirm("Delete this cell?")) {
          const idx = notebookModel.findIndex((c) => c.id === cell.id);
          if (idx !== -1) notebookModel.splice(idx, 1);
          saveNotebook();
          renderNotebook();
        }
      });
    }

    return section;
  }

  function renderNotebook() {
    // clear DOM
    const notebookEl = document.getElementById("notebook");
    while (notebookEl.firstChild) notebookEl.removeChild(notebookEl.firstChild);
    for (const c of notebookModel) {
      const el = createCellElement(c);
      notebookEl.appendChild(el);
    }
    // attempt to ensure editors exist for rendered cells
    try {
      refreshEditors();
    } catch (e) {
      /* ignore */
    }
  }

  // initialize notebook (load saved or default)
  loadNotebook();
  renderNotebook();

  // Autosave: periodically persist any open tabs that are marked unsaved.
  // This is a gentle autosave (every 5s) to reduce chance of data loss.
  try {
    const AUTOSAVE_INTERVAL = 5000;
    setInterval(async () => {
      try {
        for (const [name, tab] of openTabs) {
          if (tab && tab.unsaved) {
            // Make this tab active to reuse existing saveCurrentFile logic
            try {
              setActiveTab(name);
              // small yield to allow UI updates
              await new Promise((r) => setTimeout(r, 10));
              saveCurrentFile();
              appendToConsole(`[autosave] saved ${name}`);
            } catch (e) {
              console.warn("autosave failed for", name, e);
            }
          }
        }
      } catch (e) {
        console.warn("autosave iteration error", e);
      }
    }, AUTOSAVE_INTERVAL);
  } catch (e) {
    console.warn("Could not start autosave", e);
  }

  // Global keyboard shortcuts
  // - Cmd/Ctrl+S -> Save current file
  // - Shift+Enter -> Run current file (if a file tab is active)
  // - Ctrl/Cmd+P -> quick prompt to open file by name
  try {
    document.addEventListener("keydown", async (ev) => {
      // Cmd/Ctrl+S: save
      if ((ev.ctrlKey || ev.metaKey) && ev.key.toLowerCase() === "s") {
        ev.preventDefault();
        try {
          saveCurrentFile();
          appendToConsole("[kbd] Saved current file");
        } catch (e) {
          appendToConsole(`[kbd] Save failed: ${String(e)}`);
        }
        return;
      }
      // Shift+Enter: run current file if any
      if (ev.shiftKey && !ev.ctrlKey && !ev.metaKey && ev.key === "Enter") {
        // prefer running active file; if none, fallback to run focused cell if present
        ev.preventDefault();
        try {
          const activeName = getActiveTabName();
          if (activeName) {
            runCurrentFile();
            appendToConsole(`[kbd] Running file: ${activeName}`);
          } else {
            // try to find a focused cell run button
            const focused = document.activeElement;
            const cell =
              focused && focused.closest ? focused.closest(".cell") : null;
            if (cell) {
              const runBtn = cell.querySelector(".run");
              if (runBtn) runBtn.click();
            }
          }
        } catch (e) {
          appendToConsole(`[kbd] Run failed: ${String(e)}`);
        }
        return;
      }
      // Cmd/Ctrl+P: quick open prompt
      if ((ev.ctrlKey || ev.metaKey) && ev.key.toLowerCase() === "p") {
        ev.preventDefault();
        try {
          const name = prompt("Open file (name):");
          if (name) openFile(name);
        } catch (e) {}
      }
    });
  } catch (e) {
    console.warn("Global keyboard shortcuts init failed", e);
  }
})();
