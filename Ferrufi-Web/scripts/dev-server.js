#!/usr/bin/env node
/**
 * dev-server.js
 *
 * Small static file server that is Bun-friendly but also works under Node.
 * Serves the parent directory of this script (default: the Ferrufi-Web directory).
 *
 * Usage:
 *   node scripts/dev-server.js               # serve default dir on port 8000
 *   node scripts/dev-server.js 3000          # serve on port 3000
 *   node scripts/dev-server.js --port 3000   # same
 *   node scripts/dev-server.js --root ./public --port 8080
 *
 * When run under Bun this uses `Bun.serve` for best performance. Under Node it uses a tiny
 * http server and streams files with proper Content-Type headers (including `.wasm`).
 */

"use strict";

const path = require("path");
const fs = require("fs");
const http = require("http");

const argv = process.argv.slice(2);

function parseArgs(args) {
  let port = process.env.PORT ? Number(process.env.PORT) : 8000;
  let root = path.join(__dirname, "..");

  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === "--help" || a === "-h") {
      return { help: true };
    } else if (a === "--port" || a === "-p") {
      port = Number(args[i + 1]);
      i++;
    } else if (a === "--root" || a === "-r") {
      root = args[i + 1];
      i++;
    } else if (!Number.isNaN(Number(a))) {
      port = Number(a);
    } else {
      // treat unknown first positional arg as root if it's a path
      if (!root || root === path.join(__dirname, "..")) {
        root = a;
      }
    }
  }

  return { port: Number(port) || 8000, root: path.resolve(root) };
}

const opts = parseArgs(argv);
if (opts.help) {
  console.log("dev-server - small static server (Bun-friendly)\n");
  console.log("Usage:");
  console.log("  node scripts/dev-server.js [PORT] [--root PATH] [--port N]");
  console.log("");
  process.exit(0);
}

const PORT = opts.port;
const ROOT = opts.root;

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".htm": "text/html; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".wasm": "application/wasm",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".txt": "text/plain; charset=utf-8",
  ".map": "application/json; charset=utf-8",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
  ".ttf": "font/ttf",
  ".eot": "application/vnd.ms-fontobject",
};

function contentTypeFor(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  return MIME[ext] || "application/octet-stream";
}

function safeJoin(base, requestPath) {
  // Ensure we don't allow paths outside the base directory
  // Decode URI components safely
  let safePath;
  try {
    safePath = decodeURIComponent(requestPath);
  } catch (e) {
    safePath = requestPath;
  }

  // Strip query and hash
  safePath = safePath.split("?")[0].split("#")[0];

  // Prevent directory traversal
  const resolvedPath = path.resolve(base, "." + path.sep + safePath);
  if (!resolvedPath.startsWith(path.resolve(base))) {
    return null;
  }
  return resolvedPath;
}

function send404Node(res) {
  res.statusCode = 404;
  res.setHeader("Content-Type", "text/plain; charset=utf-8");
  res.end("404 Not Found");
}

function send500Node(res, err) {
  res.statusCode = 500;
  res.setHeader("Content-Type", "text/plain; charset=utf-8");
  res.end(`500 Internal Server Error\n\n${String(err)}`);
}

// Node-based fallback server
function startNodeServer(port, root) {
  const server = http.createServer(async (req, res) => {
    try {
      const url = new URL(req.url, `http://${req.headers.host}`);
      let pathname = url.pathname;

      // map '/' -> '/index.html'
      if (pathname.endsWith("/")) {
        pathname = pathname + "index.html";
      }

      const filePath = safeJoin(root, pathname);
      if (!filePath) {
        res.statusCode = 403;
        res.setHeader("Content-Type", "text/plain; charset=utf-8");
        res.end("403 Forbidden");
        return;
      }

      let stat;
      try {
        stat = await fs.promises.stat(filePath);
      } catch (e) {
        send404Node(res);
        return;
      }

      if (stat.isDirectory()) {
        // try index.html
        const indexFile = path.join(filePath, "index.html");
        try {
          const s = await fs.promises.stat(indexFile);
          if (s.isFile()) {
            serveFileNode(indexFile, res);
            return;
          }
        } catch (e) {
          send404Node(res);
          return;
        }
      } else if (stat.isFile()) {
        serveFileNode(filePath, res);
        return;
      } else {
        send404Node(res);
        return;
      }
    } catch (err) {
      send500Node(res, err);
    }
  });

  server.listen(port, () => {
    console.log(`Serving ${root} at http://localhost:${port}`);
    console.log("Press Ctrl+C to stop");
  });

  server.on("error", (err) => {
    console.error("Server error:", err);
    process.exit(1);
  });
}

function serveFileNode(filePath, res) {
  const ct = contentTypeFor(filePath);
  const headers = {
    "Content-Type": ct,
    "Cache-Control": "no-cache",
    // Minimal CORS so if you build tools that fetch from other origins they work
    "Access-Control-Allow-Origin": "*",
  };

  // Special headers for wasm can help in some setups (optional)
  if (filePath.endsWith(".wasm")) {
    headers["Cross-Origin-Resource-Policy"] = "same-origin";
  }

  res.writeHead(200, headers);
  const stream = fs.createReadStream(filePath);
  stream.on("error", (err) => {
    console.error("Stream error while serving", filePath, err);
    try {
      res.end();
    } catch (_) {}
  });
  stream.pipe(res);
}

// Bun-based server
async function startBunServer(port, root) {
  // Persistent kernel (mufiz worker) manager.
  // This starts a long-running worker process (scripts/mufiz_worker.js) which keeps
  // the native runtime in memory across requests. Requests are queued and executed
  // sequentially; the worker prints JSON start/end markers which we use to
  // capture the runtime's stdout for each request.
  let _kernelProc = null;
  let _kernelBuf = "";
  let _kernelErrBuf = "";
  let _kernelQueue = []; // queue of { id, resolve, reject, stderr }
  let _kernelBusy = false;
  const _decoder = new TextDecoder();

  // SSE clients registry: stores send functions for active SSE clients.
  // Each sendFn accepts a JSON string and will be enqueued to the client's stream.
  const _sseClients = new Set();

  // Register an SSE client. `sendFn` is a function(string) that will be invoked to push
  // an "data: <json>\n\n" chunk to the client's event stream. Returns a remover function.
  function addSSEClient(sendFn) {
    if (typeof sendFn !== "function") return () => {};
    _sseClients.add(sendFn);
    // Return a removal callback
    return () => {
      try {
        _sseClients.delete(sendFn);
      } catch (e) {
        // ignore
      }
    };
  }

  // Broadcast a JSON-serializable object to all connected SSE clients.
  // The object will be stringified once and sent to each client.
  function broadcastSSE(obj) {
    try {
      const payload = typeof obj === "string" ? obj : JSON.stringify(obj);
      for (const sendFn of Array.from(_sseClients)) {
        try {
          sendFn(payload);
        } catch (e) {
          // If a client sendFn errors, remove it to avoid repeated failures.
          try {
            _sseClients.delete(sendFn);
          } catch (ee) {}
        }
      }
    } catch (e) {
      // best-effort broadcasting, ignore errors
    }
  }

  function _mkId() {
    return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
  }

  async function startKernel() {
    // If a kernel is already running, return it.
    if (_kernelProc) return _kernelProc;

    const scriptPath = path.join(root, "scripts", "mufiz_worker.js");

    // Internal restart/backoff state (persisted across start attempts)
    _kernelManualShutdown = false;
    _kernelRestartAttempts =
      typeof _kernelRestartAttempts === "number" ? _kernelRestartAttempts : 0;

    // Helper to schedule an automatic restart with exponential backoff
    function scheduleRestart() {
      // if manual shutdown was requested, do not auto-restart
      if (_kernelManualShutdown) return;
      _kernelRestartAttempts = (_kernelRestartAttempts || 0) + 1;
      const attempt = _kernelRestartAttempts;
      // exponential backoff base (ms) with cap
      const base = 250;
      const maxDelay = 30 * 1000;
      const delay = Math.min(
        maxDelay,
        Math.pow(2, Math.min(10, attempt)) * base,
      );
      console.warn(
        `[kernel] scheduling restart attempt #${attempt} in ${delay}ms`,
      );
      try {
        broadcastSSE({
          type: "kernel",
          event: "restart_scheduled",
          attempt,
          delay,
        });
      } catch (e) {}
      // clear any existing restart timer
      try {
        if (typeof _kernelRestartTimer !== "undefined" && _kernelRestartTimer) {
          clearTimeout(_kernelRestartTimer);
        }
      } catch (e) {}
      _kernelRestartTimer = setTimeout(async () => {
        try {
          console.warn("[kernel] auto-restart triggered");
          await startKernel();
        } catch (e) {
          console.error("[kernel] auto-restart failed:", e);
          // schedule next attempt
          scheduleRestart();
        }
      }, delay);
    }

    // spawn the kernel process
    _kernelProc = Bun.spawn({
      cmd: ["bun", scriptPath],
      cwd: root,
      stdout: "pipe",
      stderr: "pipe",
      stdin: "pipe",
    });

    // reset runtime buffers/state for this new process
    _kernelBuf = "";
    _kernelErrBuf = "";

    // stdout reader: accumulate into buffer and try to satisfy queued jobs
    (async () => {
      try {
        const reader = _kernelProc.stdout.getReader();
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          const chunk = _decoder.decode(value);
          _kernelBuf += chunk;
          _processKernelBuffer();
        }
      } catch (e) {
        console.error("[kernel] stdout reader error", e);
      }
    })();

    // stderr reader: parse NDJSON-style messages and route stderr text and structured diagnostics
    // into the current job when possible. Worker emits JSON-lines for structured messages:
    //   {"mufiz":"error","id":"...","message":"...","line":12}
    // We attempt to parse each newline-delimited JSON object. If parsing fails, we append raw text.
    (async () => {
      try {
        const r = _kernelProc.stderr.getReader();
        // Maintain a small residual buffer for partial lines
        let stderrResidual = "";
        while (true) {
          const { done, value } = await r.read();
          if (done) break;
          const chunk = _decoder.decode(value);
          // Prepend any residual from last read and split into lines
          let combined = stderrResidual + chunk;
          const lines = combined.split("\n");
          // Last element may be partial; keep as residual
          stderrResidual = lines.pop();

          for (const rawLine of lines) {
            const line = rawLine.trim();
            if (!line) continue;
            let parsed = null;
            try {
              parsed = JSON.parse(line);
            } catch (e) {
              parsed = null;
            }

            if (parsed && typeof parsed === "object" && parsed.mufiz) {
              // Structured worker event on stderr: route into diagnostics if it references an id,
              // otherwise append to global kernel err buffer.
              const headJob = _kernelQueue.length ? _kernelQueue[0] : null;
              if (
                headJob &&
                headJob.state === "running" &&
                parsed.id &&
                parsed.id === headJob.id
              ) {
                // Ensure diagnostics array exists
                headJob.diagnostics = headJob.diagnostics || [];
                // Map common severity keys
                const severity =
                  parsed.mufiz === "error"
                    ? "error"
                    : parsed.mufiz === "warn"
                      ? "warning"
                      : "info";
                const diag = {
                  id: parsed.id,
                  severity,
                  message:
                    parsed.message || parsed.msg || JSON.stringify(parsed),
                };
                // include optional line/col if present
                if (typeof parsed.line !== "undefined") diag.line = parsed.line;
                if (typeof parsed.col !== "undefined") diag.col = parsed.col;
                headJob.diagnostics.push(diag);
                // Also append human-readable form to stderr text
                headJob.stderr =
                  (headJob.stderr || "") +
                  `[${diag.severity}] ${diag.message}\n`;
              } else {
                // Not for current job: accumulate in global err buffer
                _kernelErrBuf += line + "\n";
              }
            } else {
              // Raw stderr text: attach to current job if running, otherwise global err buffer
              if (_kernelQueue.length && _kernelQueue[0].state === "running") {
                _kernelQueue[0].stderr =
                  (_kernelQueue[0].stderr || "") + rawLine + "\n";
              } else {
                _kernelErrBuf += rawLine + "\n";
              }
            }
          }
        }

        // If there is leftover partial content, stash it in the global buffer so it isn't lost.
        if (stderrResidual) {
          if (_kernelQueue.length && _kernelQueue[0].state === "running") {
            _kernelQueue[0].stderr =
              (_kernelQueue[0].stderr || "") + stderrResidual;
          } else {
            _kernelErrBuf += stderrResidual;
          }
        }
      } catch (e) {
        console.error("[kernel] stderr reader error", e);
      }
    })();

    // Monitor kernel exit and auto-restart if it crashed unexpectedly.
    (async () => {
      try {
        // Wait for process to exit (Bun exposes .exited promise on spawn result)
        const exitInfo = await _kernelProc.exited;
        // Normalize exit code/message
        let code = null;
        try {
          code =
            exitInfo && typeof exitInfo.code !== "undefined"
              ? exitInfo.code
              : exitInfo;
        } catch (e) {
          code = exitInfo;
        }
        console.warn("[kernel] process exited", code);
        try {
          broadcastSSE({
            type: "kernel",
            event: "exited",
            pid: _kernelProc && _kernelProc.pid ? _kernelProc.pid : null,
            code,
          });
        } catch (e) {}

        // Mark that the process is gone and clear buffers
        const prevPid = _kernelProc && _kernelProc.pid ? _kernelProc.pid : null;
        _kernelProc = null;
        // Preserve any global error residue
        _kernelBuf = "";
        _kernelErrBuf = "";

        // Reject any queued jobs because the kernel died
        while (_kernelQueue.length) {
          const j = _kernelQueue.shift();
          try {
            j.reject(new Error("kernel exited unexpectedly"));
          } catch (e) {}
        }

        // If this was not initiated by a manual shutdown, schedule an automatic restart with backoff
        if (!_kernelManualShutdown) {
          scheduleRestart();
        } else {
          // clear manual shutdown flag so future starts behave normally
          _kernelManualShutdown = false;
        }
      } catch (e) {
        console.error("[kernel] monitor error", e);
        // If the monitor itself failed, ensure we attempt to restart
        scheduleRestart();
      }
    })();

    // Broadcast kernel start to any SSE listeners so frontends can update status
    try {
      broadcastSSE({
        type: "kernel",
        event: "started",
        pid: _kernelProc && _kernelProc.pid ? _kernelProc.pid : null,
      });
    } catch (e) {
      // best-effort: do not fail kernel startup on broadcast error
    }

    return _kernelProc;
  }

  function _processKernelBuffer() {
    // Only handle the head-of-queue job (we enforce sequential execution)
    if (!_kernelQueue.length) return;
    const job = _kernelQueue[0];
    const startMarker = `{"mufiz":"start","id":"${job.id}"`;
    const endMarker = `{"mufiz":"end","id":"${job.id}"`;
    const startIdx = _kernelBuf.indexOf(startMarker);
    const endIdx = _kernelBuf.indexOf(endMarker);
    if (startIdx !== -1 && endIdx !== -1 && endIdx > startIdx) {
      // find the newline after the start marker; content between that and endIdx is runtime output
      const afterStart = _kernelBuf.indexOf("\n", startIdx);
      const bodyStart = afterStart >= 0 ? afterStart + 1 : startIdx;
      const endLineEnd = _kernelBuf.indexOf("\n", endIdx);
      const endLine =
        endLineEnd >= 0
          ? _kernelBuf.substring(endIdx, endLineEnd)
          : _kernelBuf.substring(endIdx);
      const captured = _kernelBuf.substring(bodyStart, endIdx);
      // cut processed portion out of buffer
      _kernelBuf =
        endLineEnd >= 0
          ? _kernelBuf.substring(endLineEnd + 1)
          : _kernelBuf.substring(endIdx + endLine.length);
      // parse rc from endLine
      let rc = null;
      try {
        const parsed = JSON.parse(endLine);
        rc = typeof parsed.rc !== "undefined" ? parsed.rc : null;
      } catch (e) {
        // ignore parse errors
      }
      const stderr = job.stderr || "";
      // Broadcast structured job events to SSE clients for realtime UI updates
      try {
        // job started
        broadcastSSE({ type: "job", event: "start", id: job.id });
      } catch (e) {}
      try {
        // stdout chunk (the captured output between start/end markers)
        if (captured && captured.length) {
          broadcastSSE({
            type: "job",
            event: "stdout",
            id: job.id,
            chunk: captured,
          });
        }
      } catch (e) {}
      try {
        // stderr chunk (if present)
        if (stderr && stderr.length) {
          broadcastSSE({
            type: "job",
            event: "stderr",
            id: job.id,
            chunk: stderr,
          });
        }
      } catch (e) {}
      try {
        // final end event with exit code
        broadcastSSE({ type: "job", event: "end", id: job.id, rc });
      } catch (e) {}
      try {
        job.resolve({
          stdout: captured.trim(),
          stderr,
          rc,
          diagnostics: job.diagnostics || [],
        });
      } catch (e) {
        job.reject(e);
      } finally {
        _kernelQueue.shift();
      }
    }
  }

  // Enqueue code to execute on persistent kernel. Returns { stdout, stderr, rc }.
  async function runOnKernel(code) {
    await startKernel();
    return await new Promise((resolve, reject) => {
      const id = _mkId();
      // job now tracks diagnostics array and has an explicit 'state' that flips to 'running'
      const job = {
        id,
        code,
        resolve,
        reject,
        stderr: "",
        diagnostics: [],
        state: "queued",
      };
      _kernelQueue.push(job);
      // write JSON-line to worker stdin and mark as running so stderr routing can attach to it
      try {
        const payload =
          JSON.stringify({
            type: "exec",
            id,
            source: Buffer.from(code || "").toString("base64"),
            b64: true,
          }) + "\n";
        _kernelProc.stdin.write(payload);
        // mark the head job as running (we operate sequentially so this is safe)
        if (_kernelQueue.length && _kernelQueue[0].id === id) {
          _kernelQueue[0].state = "running";
        } else {
          // ensure this job will be marked running once it becomes head; other logic in process loop will handle it
          job.state = "running";
        }
      } catch (e) {
        _kernelQueue = _kernelQueue.filter((j) => j !== job);
        return reject(e);
      }
    });
  }

  // Stop the persistent kernel gracefully (if running).
  // Returns { ok: true } on success or { ok: false, message: ... } on failure.
  async function stopKernel() {
    if (!_kernelProc) {
      return { ok: false, message: "no kernel" };
    }
    try {
      // Ask the kernel to shutdown gracefully
      try {
        _kernelProc.stdin.write(JSON.stringify({ type: "shutdown" }) + "\n");
      } catch (e) {
        // ignore - maybe pipe closed
      }
      // allow small grace period for the worker to exit
      await new Promise((r) => setTimeout(r, 150));
      try {
        // attempt to kill if it's still alive
        _kernelProc.kill();
      } catch (e) {
        // ignore kill errors
      }
      // clear internal state
      _kernelProc = null;
      _kernelBuf = "";
      _kernelErrBuf = "";
      _kernelQueue = [];
      return { ok: true };
    } catch (e) {
      return { ok: false, error: String(e && e.message ? e.message : e) };
    }
  }

  // Restart the kernel (stop if running, then start a new one).
  async function restartKernel() {
    try {
      await stopKernel();
      await startKernel();
      return { ok: true };
    } catch (e) {
      return { ok: false, error: String(e && e.message ? e.message : e) };
    }
  }

  // Bun.serve handler expects a fetch-like handler
  const handler = async (req) => {
    try {
      const url = new URL(req.url);
      let pathname = decodeURIComponent(url.pathname);

      // SSE endpoint for kernel events (clients can use EventSource to listen)
      // GET /api/kernel/events
      if (pathname === "/api/kernel/events" && req.method === "GET") {
        // Create a ReadableStream that will be fed by the kernel manager via addSSEClient(sendFn)
        const stream = new ReadableStream({
          start(controller) {
            // sendFn should accept a JSON string and enqueue an SSE data: event
            const sendFn = (jsonStr) => {
              try {
                controller.enqueue(`data: ${jsonStr}\n\n`);
              } catch (e) {
                // if enqueue fails, ignore - client may have closed
              }
            };
            const remove = addSSEClient(sendFn);
            // When controller closes, remove from clients
            controller.byobRequest = controller.byobRequest; // no-op usage to avoid lint
            // keep the stream alive; removal will be handled on cancel/close
            controller._sseRemove = remove;
          },
          cancel(reason) {
            // remove client if present
            try {
              if (this._sseRemove) this._sseRemove();
            } catch (e) {}
          },
        });
        return new Response(stream, {
          status: 200,
          headers: {
            "Content-Type": "text/event-stream",
            "Cache-Control": "no-cache",
            Connection: "keep-alive",
            "Access-Control-Allow-Origin": "*",
          },
        });
      }

      // API: /api/init - warm the runtime (best-effort)
      if (pathname === "/api/init" && req.method === "POST") {
        try {
          const body = await req.json().catch(() => ({}));
          const source = body && body.source ? String(body.source) : "";
          // Use the persistent kernel when available (keeps runtime state between calls)
          const result = await runOnKernel(source);
          return new Response(JSON.stringify(result), {
            status: 200,
            headers: {
              "Content-Type": "application/json; charset=utf-8",
              "Access-Control-Allow-Origin": "*",
            },
          });
        } catch (err) {
          return new Response(
            JSON.stringify({
              error: String(err && err.message ? err.message : err),
            }),
            {
              status: 500,
              headers: {
                "Content-Type": "application/json; charset=utf-8",
                "Access-Control-Allow-Origin": "*",
              },
            },
          );
        }
      }

      // Kernel control endpoints
      if (pathname === "/api/kernel/status") {
        if (req.method !== "GET") {
          return new Response("Method Not Allowed", {
            status: 405,
            headers: { "Content-Type": "text/plain; charset=utf-8" },
          });
        }
        const alive = !!_kernelProc;
        const pid = _kernelProc && _kernelProc.pid ? _kernelProc.pid : null;
        return new Response(
          JSON.stringify({ alive, pid, stdoutBufferLen: _kernelBuf.length }),
          {
            status: 200,
            headers: {
              "Content-Type": "application/json; charset=utf-8",
              "Access-Control-Allow-Origin": "*",
            },
          },
        );
      }

      if (pathname === "/api/kernel/stop") {
        if (req.method !== "POST") {
          return new Response("Method Not Allowed", {
            status: 405,
            headers: { "Content-Type": "text/plain; charset=utf-8" },
          });
        }
        try {
          const res = await stopKernel();
          return new Response(JSON.stringify(res), {
            status: 200,
            headers: {
              "Content-Type": "application/json; charset=utf-8",
              "Access-Control-Allow-Origin": "*",
            },
          });
        } catch (err) {
          return new Response(
            JSON.stringify({
              ok: false,
              error: String(err && err.message ? err.message : err),
            }),
            {
              status: 500,
              headers: {
                "Content-Type": "application/json; charset=utf-8",
                "Access-Control-Allow-Origin": "*",
              },
            },
          );
        }
      }

      if (pathname === "/api/kernel/restart") {
        if (req.method !== "POST") {
          return new Response("Method Not Allowed", {
            status: 405,
            headers: { "Content-Type": "text/plain; charset=utf-8" },
          });
        }
        try {
          const res = await restartKernel();
          return new Response(JSON.stringify(res), {
            status: 200,
            headers: {
              "Content-Type": "application/json; charset=utf-8",
              "Access-Control-Allow-Origin": "*",
            },
          });
        } catch (err) {
          return new Response(
            JSON.stringify({
              ok: false,
              error: String(err && err.message ? err.message : err),
            }),
            {
              status: 500,
              headers: {
                "Content-Type": "application/json; charset=utf-8",
                "Access-Control-Allow-Origin": "*",
              },
            },
          );
        }
      }

      // Workspace file API (P1) - list/read/write files under server root
      // GET  /api/workspace/list?path=<relative path>   -> list directory (defaults to ".")
      // GET  /api/workspace/read?path=<relative path>   -> read file contents
      // POST /api/workspace/write                        -> write file { path, content }
      if (pathname === "/api/workspace/list") {
        if (req.method !== "GET") {
          return new Response("Method Not Allowed", {
            status: 405,
            headers: { "Content-Type": "text/plain; charset=utf-8" },
          });
        }
        try {
          const rel = url.searchParams.get("path") || ".";
          const fsPath = safeJoin(root, rel);
          if (!fsPath) {
            return new Response("Forbidden", {
              status: 403,
              headers: { "Content-Type": "text/plain; charset=utf-8" },
            });
          }
          const entries = await fs.promises.readdir(fsPath, {
            withFileTypes: true,
          });
          const filesList = await Promise.all(
            entries.map(async (ent) => {
              const full = path.join(fsPath, ent.name);
              let stat = null;
              try {
                stat = await fs.promises.stat(full);
              } catch (e) {
                // ignore stat errors for individual entries
              }
              return {
                name: ent.name,
                path: path.relative(root, full).replace(/\\/g, "/"),
                isDirectory: ent.isDirectory(),
                size: stat && stat.size ? stat.size : 0,
                mtime: stat && stat.mtime ? stat.mtime.getTime() : null,
              };
            }),
          );
          return new Response(JSON.stringify({ files: filesList }), {
            status: 200,
            headers: {
              "Content-Type": "application/json; charset=utf-8",
              "Access-Control-Allow-Origin": "*",
            },
          });
        } catch (err) {
          return new Response(
            JSON.stringify({
              error: String(err && err.message ? err.message : err),
            }),
            {
              status: 500,
              headers: {
                "Content-Type": "application/json; charset=utf-8",
                "Access-Control-Allow-Origin": "*",
              },
            },
          );
        }
      }

      if (pathname === "/api/workspace/read") {
        if (req.method !== "GET") {
          return new Response("Method Not Allowed", {
            status: 405,
            headers: { "Content-Type": "text/plain; charset=utf-8" },
          });
        }
        try {
          const rel = url.searchParams.get("path");
          if (!rel) {
            return new Response(
              JSON.stringify({ error: "missing 'path' query parameter" }),
              {
                status: 400,
                headers: {
                  "Content-Type": "application/json; charset=utf-8",
                  "Access-Control-Allow-Origin": "*",
                },
              },
            );
          }
          const filePath = safeJoin(root, rel);
          if (!filePath) {
            return new Response("Forbidden", {
              status: 403,
              headers: { "Content-Type": "text/plain; charset=utf-8" },
            });
          }
          const st = await fs.promises.stat(filePath).catch(() => null);
          if (!st || !st.isFile()) {
            return new Response(
              JSON.stringify({ error: "not a file or does not exist" }),
              {
                status: 404,
                headers: {
                  "Content-Type": "application/json; charset=utf-8",
                  "Access-Control-Allow-Origin": "*",
                },
              },
            );
          }
          const content = await fs.promises.readFile(filePath, "utf8");
          return new Response(JSON.stringify({ path: rel, content }), {
            status: 200,
            headers: {
              "Content-Type": "application/json; charset=utf-8",
              "Access-Control-Allow-Origin": "*",
            },
          });
        } catch (err) {
          return new Response(
            JSON.stringify({
              error: String(err && err.message ? err.message : err),
            }),
            {
              status: 500,
              headers: {
                "Content-Type": "application/json; charset=utf-8",
                "Access-Control-Allow-Origin": "*",
              },
            },
          );
        }
      }

      if (pathname === "/api/workspace/write") {
        if (req.method !== "POST") {
          return new Response("Method Not Allowed", {
            status: 405,
            headers: { "Content-Type": "text/plain; charset=utf-8" },
          });
        }
        try {
          const body = await req.json().catch(() => ({}));
          const rel = body && body.path ? String(body.path) : null;
          const content =
            body && typeof body.content !== "undefined"
              ? String(body.content)
              : "";
          if (!rel) {
            return new Response(
              JSON.stringify({ error: "missing 'path' in body" }),
              {
                status: 400,
                headers: {
                  "Content-Type": "application/json; charset=utf-8",
                  "Access-Control-Allow-Origin": "*",
                },
              },
            );
          }
          const filePath = safeJoin(root, rel);
          if (!filePath) {
            return new Response("Forbidden", {
              status: 403,
              headers: { "Content-Type": "text/plain; charset=utf-8" },
            });
          }
          // ensure parent directory exists
          const parent = path.dirname(filePath);
          await fs.promises.mkdir(parent, { recursive: true });
          await fs.promises.writeFile(filePath, content, "utf8");
          return new Response(JSON.stringify({ ok: true, path: rel }), {
            status: 200,
            headers: {
              "Content-Type": "application/json; charset=utf-8",
              "Access-Control-Allow-Origin": "*",
            },
          });
        } catch (err) {
          return new Response(
            JSON.stringify({
              ok: false,
              error: String(err && err.message ? err.message : err),
            }),
            {
              status: 500,
              headers: {
                "Content-Type": "application/json; charset=utf-8",
                "Access-Control-Allow-Origin": "*",
              },
            },
          );
        }
      }

      // Workspace file operations: rename, delete, mkdir (P1)
      // POST /api/workspace/rename  { oldPath, newPath }
      if (pathname === "/api/workspace/rename") {
        if (req.method !== "POST") {
          return new Response("Method Not Allowed", {
            status: 405,
            headers: { "Content-Type": "text/plain; charset=utf-8" },
          });
        }
        try {
          const body = await req.json().catch(() => ({}));
          const oldRel = body && body.oldPath ? String(body.oldPath) : null;
          const newRel = body && body.newPath ? String(body.newPath) : null;
          if (!oldRel || !newRel) {
            return new Response(
              JSON.stringify({
                error: "missing 'oldPath' or 'newPath' in body",
              }),
              {
                status: 400,
                headers: {
                  "Content-Type": "application/json; charset=utf-8",
                  "Access-Control-Allow-Origin": "*",
                },
              },
            );
          }
          const oldPath = safeJoin(root, oldRel);
          const newPath = safeJoin(root, newRel);
          if (!oldPath || !newPath) {
            return new Response("Forbidden", {
              status: 403,
              headers: { "Content-Type": "text/plain; charset=utf-8" },
            });
          }
          // ensure source exists
          const st = await fs.promises.stat(oldPath).catch(() => null);
          if (!st) {
            return new Response(
              JSON.stringify({ ok: false, error: "source does not exist" }),
              {
                status: 404,
                headers: {
                  "Content-Type": "application/json; charset=utf-8",
                  "Access-Control-Allow-Origin": "*",
                },
              },
            );
          }
          // ensure destination parent exists
          const newParent = path.dirname(newPath);
          await fs.promises.mkdir(newParent, { recursive: true });
          await fs.promises.rename(oldPath, newPath);
          return new Response(
            JSON.stringify({ ok: true, from: oldRel, to: newRel }),
            {
              status: 200,
              headers: {
                "Content-Type": "application/json; charset=utf-8",
                "Access-Control-Allow-Origin": "*",
              },
            },
          );
        } catch (err) {
          return new Response(
            JSON.stringify({
              ok: false,
              error: String(err && err.message ? err.message : err),
            }),
            {
              status: 500,
              headers: {
                "Content-Type": "application/json; charset=utf-8",
                "Access-Control-Allow-Origin": "*",
              },
            },
          );
        }
      }

      // POST /api/workspace/delete  { path, force:false }
      if (pathname === "/api/workspace/delete") {
        if (req.method !== "POST") {
          return new Response("Method Not Allowed", {
            status: 405,
            headers: { "Content-Type": "text/plain; charset=utf-8" },
          });
        }
        try {
          const body = await req.json().catch(() => ({}));
          const rel = body && body.path ? String(body.path) : null;
          const force = body && body.force ? true : false;
          if (!rel) {
            return new Response(
              JSON.stringify({ error: "missing 'path' in body" }),
              {
                status: 400,
                headers: {
                  "Content-Type": "application/json; charset=utf-8",
                  "Access-Control-Allow-Origin": "*",
                },
              },
            );
          }
          const filePath = safeJoin(root, rel);
          if (!filePath) {
            return new Response("Forbidden", {
              status: 403,
              headers: { "Content-Type": "text/plain; charset=utf-8" },
            });
          }
          const st = await fs.promises.stat(filePath).catch(() => null);
          if (!st) {
            return new Response(
              JSON.stringify({ ok: false, error: "not found" }),
              {
                status: 404,
                headers: {
                  "Content-Type": "application/json; charset=utf-8",
                  "Access-Control-Allow-Origin": "*",
                },
              },
            );
          }
          if (st.isDirectory()) {
            if (!force) {
              // refuse to delete non-empty directory unless force is true
              const ents = await fs.promises.readdir(filePath).catch(() => []);
              if (ents.length > 0) {
                return new Response(
                  JSON.stringify({
                    ok: false,
                    error:
                      "directory not empty; set force=true to remove recursively",
                  }),
                  {
                    status: 400,
                    headers: {
                      "Content-Type": "application/json; charset=utf-8",
                      "Access-Control-Allow-Origin": "*",
                    },
                  },
                );
              }
              await fs.promises.rmdir(filePath);
            } else {
              // recursive remove
              await fs.promises.rm(filePath, { recursive: true, force: true });
            }
          } else {
            await fs.promises.unlink(filePath);
          }
          return new Response(JSON.stringify({ ok: true, path: rel }), {
            status: 200,
            headers: {
              "Content-Type": "application/json; charset=utf-8",
              "Access-Control-Allow-Origin": "*",
            },
          });
        } catch (err) {
          return new Response(
            JSON.stringify({
              ok: false,
              error: String(err && err.message ? err.message : err),
            }),
            {
              status: 500,
              headers: {
                "Content-Type": "application/json; charset=utf-8",
                "Access-Control-Allow-Origin": "*",
              },
            },
          );
        }
      }

      // POST /api/workspace/mkdir { path, recursive:true }
      if (pathname === "/api/workspace/mkdir") {
        if (req.method !== "POST") {
          return new Response("Method Not Allowed", {
            status: 405,
            headers: { "Content-Type": "text/plain; charset=utf-8" },
          });
        }
        try {
          const body = await req.json().catch(() => ({}));
          const rel = body && body.path ? String(body.path) : null;
          const recursive =
            body && typeof body.recursive !== "undefined"
              ? !!body.recursive
              : true;
          if (!rel) {
            return new Response(
              JSON.stringify({ error: "missing 'path' in body" }),
              {
                status: 400,
                headers: {
                  "Content-Type": "application/json; charset=utf-8",
                  "Access-Control-Allow-Origin": "*",
                },
              },
            );
          }
          const dirPath = safeJoin(root, rel);
          if (!dirPath) {
            return new Response("Forbidden", {
              status: 403,
              headers: { "Content-Type": "text/plain; charset=utf-8" },
            });
          }
          await fs.promises.mkdir(dirPath, { recursive });
          return new Response(JSON.stringify({ ok: true, path: rel }), {
            status: 200,
            headers: {
              "Content-Type": "application/json; charset=utf-8",
              "Access-Control-Allow-Origin": "*",
            },
          });
        } catch (err) {
          return new Response(
            JSON.stringify({
              ok: false,
              error: String(err && err.message ? err.message : err),
            }),
            {
              status: 500,
              headers: {
                "Content-Type": "application/json; charset=utf-8",
                "Access-Control-Allow-Origin": "*",
              },
            },
          );
        }
      }

      // API: /api/interpret - execute code on the persistent kernel and return captured output
      if (pathname === "/api/interpret") {
        if (req.method !== "POST") {
          return new Response("Method Not Allowed", {
            status: 405,
            headers: { "Content-Type": "text/plain; charset=utf-8" },
          });
        }
        try {
          const body = await req.json();
          const source = body && body.source ? String(body.source) : "";
          const result = await runOnKernel(source);
          return new Response(JSON.stringify(result), {
            status: 200,
            headers: {
              "Content-Type": "application/json; charset=utf-8",
              "Access-Control-Allow-Origin": "*",
            },
          });
        } catch (err) {
          return new Response(
            JSON.stringify({
              error: String(err && err.message ? err.message : err),
            }),
            {
              status: 500,
              headers: {
                "Content-Type": "application/json; charset=utf-8",
                "Access-Control-Allow-Origin": "*",
              },
            },
          );
        }
      }

      // API: /api/inspect - list native symbols (helpful for debugging what the dylib exports)
      if (pathname === "/api/inspect") {
        try {
          const libPath = path.join(root, "lib", "libmufiz.dylib");
          const p = Bun.spawn({
            cmd: ["nm", "-g", libPath],
            cwd: root,
            stdout: "pipe",
            stderr: "pipe",
          });
          const out = await new Response(p.stdout).text();
          const lines = out.split("\n").filter(Boolean);
          const symbols = lines
            .map((l) => {
              const parts = l.trim().split(/\s+/);
              return parts[parts.length - 1];
            })
            .filter(Boolean);
          return new Response(JSON.stringify({ symbols, raw: out }), {
            status: 200,
            headers: {
              "Content-Type": "application/json; charset=utf-8",
              "Access-Control-Allow-Origin": "*",
            },
          });
        } catch (e) {
          return new Response(
            JSON.stringify({ error: String(e && e.message ? e.message : e) }),
            {
              status: 500,
              headers: {
                "Content-Type": "application/json; charset=utf-8",
                "Access-Control-Allow-Origin": "*",
              },
            },
          );
        }
      }

      // Fallback to static file serving (original behavior)
      if (pathname.endsWith("/")) pathname = pathname + "index.html";
      const filePath = safeJoin(root, pathname);
      if (!filePath) {
        return new Response("Forbidden", {
          status: 403,
          headers: { "Content-Type": "text/plain; charset=utf-8" },
        });
      }
      try {
        // Bun.file is efficient and streams directly
        const f = Bun.file(filePath);
        const ct = contentTypeFor(filePath);
        const headers = {
          "Content-Type": ct,
          "Cache-Control": "no-cache",
          "Access-Control-Allow-Origin": "*",
        };
        if (filePath.endsWith(".wasm")) {
          headers["Cross-Origin-Resource-Policy"] = "same-origin";
        }
        return new Response(f, { status: 200, headers });
      } catch (e) {
        return new Response("Not found", {
          status: 404,
          headers: { "Content-Type": "text/plain; charset=utf-8" },
        });
      }
    } catch (e) {
      return new Response(String(e), {
        status: 500,
        headers: { "Content-Type": "text/plain; charset=utf-8" },
      });
    }
  };

  // Start the persistent kernel eagerly so the runtime is warmed before accepting requests.
  try {
    await startKernel();
    console.log("(Bun) kernel started (persistent mufiz worker)");
    // Notify SSE listeners that the kernel is ready
    try {
      broadcastSSE({
        type: "kernel",
        event: "ready",
        pid: _kernelProc && _kernelProc.pid ? _kernelProc.pid : null,
      });
    } catch (e) {
      // ignore broadcast errors
    }
  } catch (e) {
    console.warn(
      "(Bun) kernel failed to start eagerly:",
      e && e.message ? e.message : e,
    );
    try {
      broadcastSSE({
        type: "kernel",
        event: "error",
        error: String(e && e.message ? e.message : e),
      });
    } catch (ee) {}
  }

  const server = Bun.serve({
    port,
    fetch: handler,
  });

  console.log(`(Bun) Serving ${root} at http://localhost:${port}`);
  console.log("Press Ctrl+C to stop");
  // Keep process alive; Bun.serve handles lifetime.
  return server;
}

// Entry point: detect Bun or fallback to Node
async function main() {
  // Ensure root exists
  try {
    const st = await fs.promises.stat(ROOT);
    if (!st.isDirectory()) {
      console.error(`Root path ${ROOT} is not a directory.`);
      process.exit(1);
    }
  } catch (e) {
    console.error(
      `Root path ${ROOT} does not exist:`,
      e && e.message ? e.message : e,
    );
    process.exit(1);
  }

  const isBun = typeof Bun !== "undefined" && typeof Bun.serve === "function";
  if (isBun) {
    await startBunServer(PORT, ROOT);
  } else {
    startNodeServer(PORT, ROOT);
  }
}

main().catch((err) => {
  console.error(
    "dev-server failed to start:",
    err && err.stack ? err.stack : err,
  );
  process.exit(1);
});
