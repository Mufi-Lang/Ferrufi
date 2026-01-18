# Ferrufi-Web TODO

This TODO tracks the work required to turn the current Ferrufi web notebook into a proper IDE-like experience backed by a persistent Bun FFI kernel with streaming output and diagnostics.

Status keys
- TODO: not started
- IN-PROGRESS: work has begun
- REVIEW: ready for review / testing
- DONE: completed

Priority keys
- P0: highest (blocking)
- P1: high
- P2: medium
- P3: low / nice-to-have

Estimated effort format: hours (approx).

---

## Milestones
1. Kernel streaming & robust worker manager (P0)
2. Live console + editor streaming integration (P0)
3. File-based workspace, tabs, save/load (P1)
4. Inline diagnostics & Problems pane (P1)
5. Kernel controls, auto-restart, status UI (P1)
6. UX polish: keyboard shortcuts, split panes, theming (P2)
7. Monaco integration / LSP (optional P2-P3)

---

## Top-level TODO (by priority)

### P0 - Kernel streaming & worker manager
- [ ] Add WebSocket endpoint to proxy kernel events (TODO)
  - Description: Add a WS route on the dev server to accept client connections, authenticate (local-only for now), and relay messages bi-directionally with the kernel manager.
  - Acceptance criteria:
    - Clients can open `ws://<host>/api/ws/kernel`.
    - Server broadcasts kernel `status` events and forwards `exec`/control messages to the worker.
  - Files:
    - `scripts/dev-server.js`
  - Estimate: 2–4h

- [ ] Convert worker to emit structured JSON stream events (TODO)
  - Description: Update `scripts/mufiz_worker.js` so output is emitted as newline-delimited JSON events for `start`, `stdout`, `stderr`, `status`, `end`.
  - Event example:
    ```json
    {"type":"start","id":"<uuid>","meta":{...}}
    {"type":"stdout","id":"<uuid>","chunk":"..."}
    {"type":"stderr","id":"<uuid>","chunk":"..."}
    {"type":"end","id":"<uuid>","rc":0}
    ```
  - Acceptance criteria:
    - Worker writes NDJSON to stdout that the server can parse as discrete events.
  - Files:
    - `scripts/mufiz_worker.js`
  - Estimate: 2–3h

- [ ] Add server-side kernel manager improvements (TODO)
  - Description: Kernel manager should handle starting, stopping, queuing requests while starting, and exponential-backoff restarts on crash.
  - Acceptance criteria:
    - `GET /api/kernel/status` returns accurate state (starting/ready/dead).
    - `POST /api/kernel/restart` force-restarts kernel.
    - If kernel crashes, server attempts restart with backoff and broadcasts status.
  - Files:
    - `scripts/dev-server.js`
  - Estimate: 2–4h

### P0 - Live console + editor streaming integration
- [ ] WebSocket client integration (TODO)
  - Description: Client opens WS, sends `exec` messages; receives streaming `stdout`/`stderr` events and appends them to console/cell output.
  - Acceptance criteria:
    - Shift+Enter sends an `exec` message with a unique id.
    - Console/cell output updates in near-real-time as `stdout` events arrive.
  - Files:
    - `app.js`
    - `codemirror.js` (or `monaco-setup.js`)
    - `index.html`
  - Estimate: 3–5h

- [ ] HTTP fallback for single-shot runs (TODO)
  - Description: Keep `POST /api/interpret` for users who don't use WS. Server aggregates events and returns `{ stdout, stderr, rc }`.
  - Acceptance criteria:
    - `POST /api/interpret` continues to work as before.
    - When WS is present, prefer WS for streaming.
  - Files:
    - `scripts/dev-server.js`
  - Estimate: 1–2h

### P1 - File-based workspace & editor UX
- [ ] Workspace file explorer (TODO)
  - Description: Expose endpoints to list/read/write files. Implement client explorer UI.
  - Endpoints:
    - `GET /api/workspace/list`
    - `GET /api/workspace/read?path=...`
    - `POST /api/workspace/write` (body: { path, content })
  - Files:
    - `scripts/dev-server.js`
    - `app.js`
    - `index.html`, `styles.css`
  - Acceptance criteria:
    - Client can open, edit, and save files to disk in the selected workspace root.
  - Estimate: 3–5h

- [ ] Multi-tab editor with save state and unsaved indicators (TODO)
  - Description: Implement tabs, dirty state, close/reopen, and basic autosave option.
  - Files:
    - `app.js`
    - `codemirror.js` or `monaco-setup.js`
  - Acceptance criteria:
    - Multiple open files in tabs, unsaved changes are indicated, Save triggers `POST /api/workspace/write`.
  - Estimate: 2–4h

### P1 - Diagnostics & Problems pane
- [ ] Parse `stderr` for parse/line information and surface problems (TODO)
  - Description: Create mapping from runtime stderr to editor markers and Problems pane entries. If runtime includes line numbers, highlight exact lines; otherwise, create line-level annotations.
  - Acceptance criteria:
    - Errors from the kernel appear in Problems tab with file/line if available.
    - Clicking a problem navigates to the editor line.
  - Files:
    - `app.js`
    - `codemirror.js` / `monaco-setup.js`
  - Estimate: 2–3h (depends on runtime error format)

- [ ] Add inline markers (TODO)
  - Description: Use CodeMirror/Monaco APIs to underline or gutter-mark offending lines.
  - Files:
    - `codemirror.js` / `monaco-setup.js`
  - Acceptance criteria:
    - Markers visible immediately when `stderr` events arrive for a run id.
  - Estimate: 1–2h

### P1 - Kernel controls & resilience
- [ ] Kernel status indicator + restart button (TODO)
  - Description: UI shows kernel state (ready/starting/dead) and exposes manual restart/stop actions.
  - Files:
    - `index.html`
    - `app.js`
  - Acceptance criteria:
    - Kernel status auto-updates via WS or polling.
  - Estimate: 1–2h

- [ ] Auto-restart with notification (TODO)
  - Description: If kernel crashes, server attempts restart and notifies clients. Optionally, buffer small number of commands during restart.
  - Files:
    - `scripts/dev-server.js`
  - Acceptance criteria:
    - Clients see kernel state changes and toast/console message when restart occurs.
  - Estimate: 2–3h

### P2 - UX polish & optional features
- [ ] Keyboard shortcuts (Cmd/Ctrl+S, Shift+Enter, Ctrl+P) (TODO)
  - Estimate: 1–2h

- [ ] Split panes, resizable layout, theming (TODO)
  - Estimate: 3–6h

- [ ] Interactive kernel stdin support (TODO)
  - Description: Support passing stdin to worker for interactive commands (advanced).
  - Estimate: 4–8h

- [ ] Monaco + LSP integration (optional) (TODO)
  - Description: Replace CodeMirror with Monaco, wire LSP for advanced diagnostics/auto-complete.
  - Risk: heavier bundle, more setup. Consider CDN or local vendor.
  - Estimate: 1–3 days

### P3 - Tests, logging, and developer tooling
- [ ] Add unit/integration tests for:
  - Worker NDJSON parsing
  - Kernel manager restart logic
  - HTTP endpoints
  - Estimate: 4–8h
- [ ] Add verbose dev logging and a `/api/debug` endpoint to dump raw kernel stdout/stderr and in-flight requests (TODO)
  - Estimate: 1–2h

---

## Implementation notes & conventions
- Communication protocol between client/server/worker:
  - Worker must emit NDJSON JSON objects; server parses them by newline.
  - All exec requests are identified by a `uuid` to correlate start/stdout/stderr/end events.
  - Prefer streaming `stdout`/`stderr` chunks (small-ish). Server should forward events as they arrive.
- Backwards compatibility:
  - Keep `POST /api/interpret` behavior intact for non-WS clients.
  - Ensure the dev server can operate without WS clients (HTTP-only).
- Security:
  - For now, this is a local dev tool. Do not expose kernel WS or control endpoints publicly without authentication.
- Cross-platform:
  - Current native lib is macOS `libmufiz.dylib`. Keep worker code platform-aware for dlopen path differences.
- Error parsing:
  - If runtime error format lacks precise file/col information, expose error text in Problems pane with a best-effort line guess.

---

## First actionable steps (what I'll start with once you say "go")
1. Implement NDJSON worker events in `scripts/mufiz_worker.js` (emit `start`, `stdout`, `stderr`, `end`, `status`).
2. Add WS endpoint + kernel manager improvements in `scripts/dev-server.js` to proxy events and accept control messages.
3. Wire client-side WS in `app.js` to accept streaming events and append them to the console output area.
4. Keep `POST /api/interpret` as a fallback. Validate by running a simple working snippet like:
   - `print("hello from mufiz"); var a = 5; print(a);`
5. Report back with logs, example NDJSON events, and a UI demo showing real-time streaming.

---

## Notes / Open questions for you
- Editor engine choice: do you want Monaco (rich) or CodeMirror (light)? (affects estimate)
- Workspace root: Should edits operate on repo root (`Ferrufi-Web`) or a separate workspace folder?
- WebSocket vs SSE: I recommend WebSocket for bi-directional control. Confirm?

---

## Changelog
- 2026-01-15: Created initial TODO with milestone breakdown and prioritized action items.
