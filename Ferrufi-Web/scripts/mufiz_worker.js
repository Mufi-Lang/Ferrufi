#!/usr/bin/env bun
"use strict";

/**
 * mufiz_worker.js
 *
 * Persistent Bun worker that loads the native mufiz runtime via bun:ffi and
 * accepts JSON-line messages on stdin. Messages are processed sequentially and
 * keep the runtime in memory so interpreter state persists between calls.
 *
 * Protocol (JSON lines):
 *  - Exec:   {"type":"exec","id":"<optional-id>","source":"<base64 or raw>", "b64":true/false}
 *  - Init:   {"type":"init","id":"...","a":0,"b":0,"c":1}
 *  - Ping:   {"type":"ping","id":"..."} -> worker prints {"mufiz":"pong","id":...}
 *  - Shutdown: {"type":"shutdown"} -> worker exits
 *
 * Worker prints JSON markers as single-line lines:
 *  - start: {"mufiz":"start","id":"..."}
 *  - end:   {"mufiz":"end","id":"...","rc":0}
 *  - errors are printed on stderr as JSON: {"mufiz":"error","id":"...","message":"..."}
 *
 * The parent process should read stdout/stderr and extract text between start/end markers
 * to obtain runtime output for the corresponding id.
 */

const fs = require("fs");
const path = require("path");

// Utility to find the native library in common places
function findLib(provided) {
  const candidates = [];
  if (provided) candidates.push(provided);
  candidates.push(path.join(__dirname, "..", "lib", "libmufiz.dylib"));
  candidates.push(path.join(__dirname, "..", "lib", "libmufiz.so"));
  candidates.push(path.join(__dirname, "..", "lib", "libmufiz.dll"));
  for (const c of candidates) {
    try {
      if (c && fs.existsSync(c)) {
        return path.resolve(c);
      }
    } catch (e) {
      // ignore
    }
  }
  return null;
}

function mkId() {
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
}

function safeJsonParse(s) {
  try {
    return JSON.parse(s);
  } catch (e) {
    return null;
  }
}

// Try to load the library with conservative bindings, then extend if necessary.
function loadLib(libPath) {
  if (!libPath) {
    throw new Error("lib path not found");
  }
  // Conservative base bindings
  let lib = null;
  try {
    lib = Bun.FFI.dlopen(libPath, {
      mufiz_init: { parameters: ["i32", "i32", "i32"], result: "i32" },
      mufiz_interpret: { parameters: ["pointer"], result: "i32" },
      mufiz_free_cstring: { parameters: ["pointer"], result: "void" },
    });
    return lib;
  } catch (e) {
    // Try a variant that also binds `interpret` (pointer-returning)
    try {
      lib = Bun.FFI.dlopen(libPath, {
        mufiz_init: { parameters: ["i32", "i32", "i32"], result: "i32" },
        mufiz_interpret: { parameters: ["pointer"], result: "i32" },
        interpret: { parameters: ["pointer"], result: "pointer" },
        mufiz_free_cstring: { parameters: ["pointer"], result: "void" },
      });
      return lib;
    } catch (err) {
      // Final attempt: minimal, let runtime still run if possible
      try {
        lib = Bun.FFI.dlopen(libPath, {
          mufiz_init: { parameters: ["i32", "i32", "i32"], result: "i32" },
        });
        return lib;
      } catch (err2) {
        // Re-throw the original error for clarity
        throw new Error(
          `Failed to dlopen '${libPath}': ${e && e.message ? e.message : e}`,
        );
      }
    }
  }
}

// Initialize and start worker
(async function main() {
  try {
    const scriptPath = process.argv[1] || __filename;
    const libPath = findLib();
    if (!libPath) {
      console.error(
        JSON.stringify({
          mufiz: "error",
          message: "Could not find libmufiz in expected locations",
        }),
      );
      process.exit(2);
    }

    let lib;
    try {
      lib = loadLib(libPath);
    } catch (e) {
      console.error(
        JSON.stringify({
          mufiz: "error",
          message: `Failed to load library '${libPath}': ${e.message || e}`,
        }),
      );
      process.exit(3);
    }

    // Best-effort init
    try {
      if (lib.symbols && typeof lib.symbols.mufiz_init === "function") {
        try {
          lib.symbols.mufiz_init(0, 0, 1);
        } catch (e) {
          // ignore non-fatal init errors
          console.error(
            JSON.stringify({
              mufiz: "warn",
              message: `mufiz_init call failed: ${String(e && e.message ? e.message : e)}`,
            }),
          );
        }
      }
    } catch (e) {
      // ignore
    }

    // Print ready marker so a parent process can detect worker readiness
    try {
      console.log(JSON.stringify({ mufiz: "ready" }));
    } catch (e) {}

    // Simple queue to process exec requests sequentially
    let queue = [];
    let busy = false;

    function enqueue(msg) {
      queue.push(msg);
      if (!busy) processQueue();
    }

    async function processQueue() {
      if (busy) return;
      busy = true;
      while (queue.length) {
        const m = queue.shift();
        try {
          await processOne(m);
        } catch (err) {
          // ensure we report end marker even on exceptions
          try {
            console.error(
              JSON.stringify({
                mufiz: "error",
                id: m.id || null,
                message: String(err && err.message ? err.message : err),
              }),
            );
            console.log(
              JSON.stringify({ mufiz: "end", id: m.id || mkId(), rc: -1 }),
            );
          } catch (_) {}
        }
      }
      busy = false;
    }

    async function processOne(msg) {
      const id = msg.id || mkId();
      // start marker
      console.log(JSON.stringify({ mufiz: "start", id }));

      // decode source (allow raw or base64)
      let source = "";
      if (typeof msg.source === "string") {
        if (msg.b64) {
          try {
            source = Buffer.from(msg.source, "base64").toString("utf8");
          } catch (e) {
            source = "";
            console.error(
              JSON.stringify({
                mufiz: "error",
                id,
                message: `Failed to decode base64 source: ${String(
                  e && e.message ? e.message : e,
                )}`,
              }),
            );
          }
        } else {
          source = msg.source;
        }
      } else {
        source = "";
      }

      let rc = null;
      try {
        // Allow caller to specify a symbol name (best-effort) - only if it is already bound on lib
        let called = false;
        if (msg.symbol && lib.symbols && typeof lib.symbols[msg.symbol] === "function") {
          try {
            const cptr = Bun.FFI.CString(source || "");
            try {
              const r = lib.symbols[msg.symbol](cptr);
              // We don't assume return type — treat undefined as success
              rc = typeof r === "number" ? r : 0;
            } finally {
              // free cstring if provided (lib may not have a free function)
            }
            called = true;
          } catch (e) {
            console.error(
              JSON.stringify({
                mufiz: "error",
                id,
                message: `Call to symbol ${msg.symbol} failed: ${String(e && e.message ? e.message : e)}`,
              }),
            );
            rc = -1;
            called = true;
          }
        }

        if (!called) {
          // Prefer pointer-returning `interpret` if present, otherwise use `mufiz_interpret`
          if (lib.symbols && typeof lib.symbols.interpret === "function") {
            try {
              const cptr = Bun.FFI.CString(source || "");
              const resPtr = lib.symbols.interpret(cptr);
              if (resPtr) {
                try {
                  const out = Bun.FFI.read(resPtr);
                  if (out) {
                    // print runtime output directly to stdout (will occur between start/end markers)
                    process.stdout.write(out + (out.endsWith("\n") ? "" : "\n"));
                  }
                } finally {
                  if (lib.symbols.mufiz_free_cstring) {
                    try {
                      lib.symbols.mufiz_free_cstring(resPtr);
                    } catch (e) {
                      // ignore free errors
                    }
                  }
                }
              }
              rc = 0;
            } catch (e) {
              console.error(
                JSON.stringify({
                  mufiz: "error",
                  id,
                  message: `interpret(ptr) call failed: ${String(e && e.message ? e.message : e)}`,
                }),
              );
              rc = -1;
            }
          } else if (lib.symbols && typeof lib.symbols.mufiz_interpret === "function") {
            try {
              const cptr = Bun.FFI.CString(source || "");
              const r = lib.symbols.mufiz_interpret(cptr);
              rc = typeof r === "number" ? r : 0;
            } catch (e) {
              console.error(
                JSON.stringify({
                  mufiz: "error",
                  id,
                  message: `mufiz_interpret call failed: ${String(e && e.message ? e.message : e)}`,
                }),
              );
              rc = -1;
            }
          } else {
            // No interpreter symbol present
            console.error(JSON.stringify({ mufiz: "error", id, message: "No interpreter symbol found on library" }));
            rc = -1;
          }
        }
      } catch (e) {
        console.error(JSON.stringify({ mufiz: "error", id, message: String(e && e.message ? e.message : e) }));
        rc = -1;
      } finally {
        // end marker (single-line JSON)
        try {
          console.log(JSON.stringify({ mufiz: "end", id, rc }));
        } catch (e) {
          // nothing more we can do
        }
      }
    }

    // stdin line reader (line-delimited JSON)
    process.stdin.setEncoding("utf8");
    let stdinBuf = "";

    process.stdin.on("data", (chunk) => {
      stdinBuf += chunk;
      let idx;
      while ((idx = stdinBuf.indexOf("\n")) >= 0) {
        const line = stdinBuf.slice(0, idx).trim();
        stdinBuf = stdinBuf.slice(idx + 1);
        if (!line) continue;
        let msg = null;
        try {
          msg = JSON.parse(line);
        } catch (e) {
          // invalid JSON — emit error to stderr
          console.error(JSON.stringify({ mufiz: "error", message: "Invalid JSON on stdin", raw: line }));
          continue;
        }

        // dispatch messages
        if (!msg || !msg.type) {
          console.error(JSON.stringify({ mufiz: "error", message: "Malformed message", raw: line }));
          continue;
        }

        switch (msg.type) {
          case "exec":
            enqueue(msg);
            break;
          case "init":
            enqueue({ ...msg, type: "exec", source: msg.source || "", b64: !!msg.b64 });
            break;
          case "ping":
            try {
              console.log(JSON.stringify({ mufiz: "pong", id: msg.id || null }));
            } catch (e) {}
            break;
          case "shutdown":
            try {
              console.log(JSON.stringify({ mufiz: "shutting_down" }));
            } catch (e) {}
            // attempt to gracefully deinit if possible
            try {
              if (lib && lib.symbols && typeof lib.symbols.mufiz_deinit === "function") {
                try {
                  lib.symbols.mufiz_deinit();
                } catch (_) {}
              } else if (lib && lib.symbols && typeof lib.symbols.deinit_wasm === "function") {
                try {
                  lib.symbols.deinit_wasm();
                } catch (_) {}
              }
            } catch (_) {}
            process.exit(0);
            break;
          default:
            console.error(JSON.stringify({ mufiz: "error", message: `Unknown message type: ${msg.type}` }));
        }
      }
    });

    process.stdin.on("end", () => {
      // parent closed stdin — exit
      try {
        console.log(JSON.stringify({ mufiz: "stdin_closed", message: "stdin closed, exiting" }));
      } catch (e) {}
      process.exit(0);
    });

    process.on("SIGINT", () => {
      try {
        console.log(JSON.stringify({ mufiz: "signal", signal: "SIGINT" }));
      } catch (e) {}
      process.exit(0);
    });

    process.on("SIGTERM", () => {
      try {
        console.log(JSON.stringify({ mufiz: "signal", signal: "SIGTERM" }));
      } catch (e) {}
      process.exit(0);
    });
  } catch (err) {
    console.error(JSON.stringify({ mufiz: "fatal", message: String(err && err.message ? err.message : err) }));
    process.exit(99);
  }
})();
