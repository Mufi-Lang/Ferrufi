/*
  Ferrufi-Web/codemirror.js

  CodeMirror 6 dynamic loader + createEditor factory.

  - Loads CodeMirror packages on demand from esm.sh (CDN).
  - Exposes `loadCodeMirror()` which returns the downloaded modules (cached).
  - Exposes `createEditor(target, options)` which creates a CM6 editor inside `target` (HTMLElement or <textarea>)
    and returns a small API: { view, getValue, setValue, focus, destroy }.

  Usage example:
    import { createEditor } from './codemirror.js';

    // replace a <textarea> or mount into a container div
    const editor = await createEditor('#my-textarea-or-div', {
      value: 'console.log("hi");',
      language: 'javascript',
      theme: 'dark',         // 'light'|'dark'|'ferrufi' (used for CSS / page theme), CM theme applied when available
      lineNumbers: true,
      onChange: (txt) => console.log('changed', txt),
      onRun: () => console.log('run key pressed (Shift-Enter)'),
    });

    // API
    editor.getValue(); // string
    editor.setValue('new text');
    editor.focus();
    editor.destroy();

  Notes:
  - This loader tries to import convenience packages (basic-setup, lang-js, one-dark). If they are unavailable,
    it falls back to assembling a minimal extension set (line numbers, keymaps, language if available).
  - If CodeMirror modules cannot be loaded, the function gracefully falls back to a plain <textarea> that
    implements the same public API.
  - The remote imports are performed via dynamic import() with esm.sh. You can prefetch by calling loadCodeMirror().
*/

const CDN = "https://esm.sh";
let _cached = null;

/** Helper to safely pick a named export from a dynamic module with fallbacks */
function pickExport(mod, names) {
  if (!mod) return undefined;
  for (const n of names) {
    if (n in mod) return mod[n];
  }
  return undefined;
}

/**
 * Dynamically loads CodeMirror modules (and caches them).
 * Returns an object with the available exports (may be partial).
 */
export async function loadCodeMirror() {
  if (_cached) return _cached;

  const mod = {
    loaded: false,
    available: {},
  };

  // List of candidate imports (try a convenient basic pack first)
  // We use Promise.allSettled so partial success is acceptable.
  const imports = {
    basicSetup: `${CDN}/@codemirror/basic-setup`,
    jsLang: `${CDN}/@codemirror/lang-javascript`,
    oneDark: `${CDN}/@codemirror/theme-one-dark`,
    state: `${CDN}/@codemirror/state`,
    view: `${CDN}/@codemirror/view`,
    commands: `${CDN}/@codemirror/commands`,
    gutter: `${CDN}/@codemirror/gutter`,
  };

  // Launch dynamic imports in parallel
  const results = await Promise.allSettled(
    Object.values(imports).map((u) =>
      import(u).catch((e) => {
        throw e;
      }),
    ),
  );

  const keys = Object.keys(imports);
  const modules = {};
  keys.forEach((k, idx) => {
    const r = results[idx];
    modules[k] = r.status === "fulfilled" ? r.value : null;
  });

  // Map the useful exports (use pickExport to be tolerant)
  const EditorState = pickExport(modules.state, ["EditorState", "default"]);
  const EditorView = pickExport(modules.view, ["EditorView", "default"]);
  const keymap =
    pickExport(modules.view, ["keymap"]) ||
    pickExport(modules.view, ["keymaps", "keymap"]);
  const defaultKeymap =
    pickExport(modules.commands, ["defaultKeymap", "default"]) ||
    pickExport(modules.commands, ["defaultKeymap"]);
  const historyKeymap = pickExport(modules.commands, ["historyKeymap"]);
  const lineNumbers = pickExport(modules.gutter, ["lineNumbers"]);
  const basicSetup = pickExport(modules.basicSetup, ["basicSetup", "default"]);
  const javascript = pickExport(modules.jsLang, ["javascript", "default"]);
  const oneDark = pickExport(modules.oneDark, ["oneDark", "default"]);

  // Also provide EditorView.updateListener if present
  const updateListener =
    EditorView && EditorView.updateListener
      ? EditorView.updateListener
      : undefined;

  // Build the return object
  const cm = {
    EditorState,
    EditorView,
    keymap,
    defaultKeymap,
    historyKeymap,
    lineNumbers,
    basicSetup,
    javascript,
    oneDark,
    updateListener,
  };

  cm.available = {
    EditorState: !!EditorState,
    EditorView: !!EditorView,
    keymap: !!keymap,
    defaultKeymap: !!defaultKeymap,
    lineNumbers: !!lineNumbers,
    basicSetup: !!basicSetup,
    javascript: !!javascript,
    oneDark: !!oneDark,
    updateListener: !!updateListener,
  };

  cm.loaded = true;
  _cached = cm;
  return cm;
}

/**
 * Create a CodeMirror editor in `target` (selector, HTMLElement, or <textarea>).
 * Falls back to a basic textarea when CM cannot be loaded.
 *
 * Options:
 *  - value: initial string
 *  - language: 'javascript' | ... (tries to activate lang if available)
 *  - theme: 'light'|'dark'|'ferrufi'  (we also set document.body[data-theme]=theme)
 *  - lineNumbers: boolean
 *  - onChange: (value) => void
 *  - onRun: (code) => void   // called when Shift+Enter is pressed; receives selected text (or full document if no selection)
 *
 * Returns: { view?, container, getValue, setValue, focus, destroy }
 */
export async function createEditor(target, options = {}) {
  const {
    value = "",
    language = "javascript",
    theme = null,
    lineNumbers: wantLineNumbers = true,
    onChange = null,
    onRun = null,
    readOnly = false,
  } = options;

  // Helper: resolve target into element
  let targetEl = null;
  if (!target) {
    // create a container if none
    targetEl = document.createElement("div");
    document.body.appendChild(targetEl);
  } else if (typeof target === "string") {
    targetEl = document.querySelector(target);
    if (!targetEl)
      throw new Error(`createEditor: no element matching selector "${target}"`);
  } else if (target instanceof HTMLElement) {
    targetEl = target;
  } else {
    throw new Error(
      "createEditor: target must be a selector or HTMLElement or textarea",
    );
  }

  // If target is a <textarea>, we'll use it as source and hide it (so forms keep it)
  let originalTextarea = null;
  if (targetEl.tagName === "TEXTAREA") {
    originalTextarea = targetEl;
    // create a container div next to textarea
    const wrapper = document.createElement("div");
    wrapper.className = "cm-wrapper";
    targetEl.parentNode.insertBefore(wrapper, targetEl.nextSibling);
    targetEl.style.display = "none";
    targetEl = wrapper;
  }

  // Apply theme preference to page-level (editor theme switching is best-effort)
  if (theme) {
    try {
      document.body.setAttribute("data-theme", theme);
    } catch (e) {}
  }

  // Attempt to load CodeMirror modules
  let cm = null;
  try {
    cm = await loadCodeMirror();
  } catch (err) {
    console.warn("CodeMirror modules failed to load:", err);
    cm = null;
  }

  // Fallback to simple textarea if CM not available
  if (!cm || !cm.available.EditorState || !cm.available.EditorView) {
    console.warn("CodeMirror not available; falling back to plain textarea.");
    // create a textarea in the container
    const ta = document.createElement("textarea");
    ta.className = "cm-fallback";
    ta.value = originalTextarea ? originalTextarea.value || value : value;
    ta.style.width = "100%";
    ta.style.minHeight = "140px";
    ta.addEventListener("input", () => {
      if (originalTextarea) originalTextarea.value = ta.value;
      if (typeof onChange === "function") onChange(ta.value);
    });
    targetEl.appendChild(ta);

    // Key handling: Shift+Enter -> onRun (pass selected text or full content)
    ta.addEventListener("keydown", (e) => {
      if (e.key === "Enter" && (e.shiftKey || e.ctrlKey)) {
        e.preventDefault();
        if (typeof onRun === "function") {
          try {
            const start = ta.selectionStart;
            const end = ta.selectionEnd;
            const sel =
              typeof start === "number" &&
              typeof end === "number" &&
              end > start
                ? ta.value.substring(start, end)
                : "";
            const code = sel && sel.trim().length ? sel : ta.value;
            onRun(code);
          } catch (err) {
            // fallback to full content if anything goes wrong
            onRun(ta.value);
          }
        }
      }
    });

    return {
      view: null,
      container: targetEl,
      getValue: () => ta.value,
      setValue: (s) => {
        ta.value = s;
        if (originalTextarea) originalTextarea.value = s;
      },
      focus: () => ta.focus(),
      destroy: () => {
        ta.remove();
        if (originalTextarea) originalTextarea.style.display = "";
      },
    };
  }

  // Build extensions list; prefer basicSetup if available
  const exts = [];

  if (cm.basicSetup) {
    // basicSetup is a convenient pack that already includes line numbers, keymaps, history, etc.
    exts.push(cm.basicSetup);
  } else {
    // Minimal assembly: line numbers, default keymap, history keymap, wrap, etc.
    if (cm.lineNumbers && wantLineNumbers) {
      exts.push(cm.lineNumbers());
    }
    if (cm.keymap && cm.defaultKeymap) {
      try {
        // Note: `keymap.of` typically comes from '@codemirror/view' or same package
        const keymapFn = cm.keymap;
        exts.push(
          keymapFn.of([
            ...(cm.defaultKeymap || []),
            ...(cm.historyKeymap ? cm.historyKeymap : []),
          ]),
        );
      } catch (e) {
        // ignore if not applicable
      }
    }
  }

  // Attach change listener if possible
  if (cm.updateListener) {
    const updateExt = cm.updateListener.of((update) => {
      if (update.docChanged) {
        const s = update.state.doc.toString();
        if (originalTextarea) originalTextarea.value = s;
        if (typeof onChange === "function") onChange(s, update);
      }
    });
    exts.push(updateExt);
  } else {
    // If updateListener is not available, we will poll on blur as a last-ditch fallback (rare)
    // (Omitted here; majority of installations provide updateListener.)
  }

  // Language support
  if (language === "javascript" && cm.javascript) {
    try {
      exts.push(cm.javascript());
    } catch (e) {
      // ignore, continue without language support
    }
  }

  // Key binding for Shift+Enter to trigger onRun
  const customRunBinding = {
    key: "Shift-Enter",
    run: (view) => {
      if (typeof onRun === "function") {
        try {
          const sel =
            view.state && view.state.selection && view.state.selection.main
              ? view.state.selection.main
              : null;
          let code = "";
          if (sel && typeof sel.from === "number" && sel.from !== sel.to) {
            // Prefer sliceString when available
            if (typeof view.state.doc.sliceString === "function") {
              code = view.state.doc.sliceString(sel.from, sel.to);
            } else {
              code = view.state.doc.toString().slice(sel.from, sel.to);
            }
          } else {
            code = view.state.doc.toString();
          }
          onRun(code);
        } catch (e) {
          // fallback to full document on error
          try {
            onRun(view.state.doc.toString());
          } catch (_) {}
        }
        return true; // handled
      }
      return false;
    },
  };
  try {
    // prefer cm.keymap if present
    if (cm.keymap) {
      exts.push(cm.keymap.of([customRunBinding]));
    }
  } catch (e) {
    // ignore
  }

  // Theme for editor: prefer oneDark when requested and available and theme indicates dark
  let cmTheme = null;
  if ((theme === "dark" || theme === "ferrufi") && cm.oneDark) {
    cmTheme = cm.oneDark;
    exts.push(cmTheme);
  }

  // Read-only option
  if (readOnly) {
    // EditorView.editable.of(false) is a typical extension to make CM read-only, but if not available,
    // we'll set the attribute on the DOM node later.
    try {
      const editable = cm.EditorView.editable
        ? cm.EditorView.editable.of(false)
        : null;
      if (editable) exts.push(editable);
    } catch (e) {}
  }

  // Create the state + view
  const state = cm.EditorState.create({
    doc: originalTextarea ? originalTextarea.value || value : value,
    extensions: exts,
  });

  const view = new cm.EditorView({
    state,
    parent: targetEl,
  });

  // If original textarea exists, keep it in sync and keep it hidden
  if (originalTextarea) {
    // initial sync
    originalTextarea.value = state.doc.toString();
  }

  // Provide helper API
  const editorAPI = {
    view,
    container: targetEl,
    getValue: () => view.state.doc.toString(),
    setValue: (s) => {
      view.dispatch({
        changes: { from: 0, to: view.state.doc.length, insert: s },
      });
      if (originalTextarea) originalTextarea.value = s;
    },
    focus: () => {
      view.focus();
    },
    destroy: () => {
      try {
        view.destroy();
      } catch (e) {}
      if (originalTextarea) originalTextarea.style.display = "";
      // If we created a wrapper container next to textarea, remove it
      if (!originalTextarea && targetEl && targetEl.parentNode) {
        // Remove the concrete editor container's children only for cleanup (don't remove targetEl itself)
        while (targetEl.firstChild) targetEl.removeChild(targetEl.firstChild);
      }
    },
  };

  return editorAPI;
}

if (typeof window !== "undefined") {
  // Expose functions for scripts that aren't loaded as modules (our app.js uses window.createEditor)
  try {
    window.createEditor = createEditor;
    window.loadCodeMirror = loadCodeMirror;
  } catch (e) {
    // Ignore in constrained environments
  }
}
