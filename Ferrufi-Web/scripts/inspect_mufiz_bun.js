#!/usr/bin/env bun
'use strict';

/**
 * inspect_mufiz_bun.js
 *
 * Bun-based inspector for the native mufiz runtime (lib/libmufiz.*).
 *
 * Capabilities:
 *  - Run `nm -g` on the dylib to list exported symbols (macOS / Unix systems)
 *  - Heuristically bind to common mufiz functions using bun:ffi
 *  - Optionally call the interpreter with `--call` (or `-c`) to test it
 *
 * Usage:
 *   bun scripts/inspect_mufiz_bun.js                 # list symbols + bound API
 *   bun scripts/inspect_mufiz_bun.js -c 'print("hi")' # attempt to interpret the given source
 *   bun scripts/inspect_mufiz_bun.js --lib /path/to/libmufiz.dylib
 *
 * Notes:
 *  - This is a helper script for local debugging. It tries to be conservative when
 *    creating FFI bindings (only binds symbols that appear exported).
 */

const fs = require('fs');
const path = require('path');

/* ----- CLI parsing ----- */
const argv = process.argv.slice(2);
let callCode = null;
let callBase64 = null;
let libPathArg = null;
let showHelp = false;

for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === '-h' || a === '--help') {
    showHelp = true;
  } else if (a === '-c' || a === '--call') {
    callCode = argv[++i] || '';
  } else if (a === '--call-b64') {
    callBase64 = argv[++i] || '';
  } else if (a === '--lib') {
    libPathArg = argv[++i] || '';
  } else {
    // unrecognized; treat as code string (convenience)
    if (!callCode && !callBase64) {
      callCode = a;
    }
  }
}

function usage() {
  console.log('');
  console.log('inspect_mufiz_bun.js - inspect native mufiz runtime and optionally call its interpreter');
  console.log('');
  console.log('Usage:');
  console.log('  bun scripts/inspect_mufiz_bun.js               # list exported symbols and try binding');
  console.log('  bun scripts/inspect_mufiz_bun.js -c "<code>"   # attempt to call the interpreter with <code>');
  console.log('  bun scripts/inspect_mufiz_bun.js --lib /path/to/libmufiz.dylib');
  console.log('');
  console.log('Note: On macOS this uses `nm -g` to discover exported symbols; on other platforms this may vary.');
  console.log('');
}

/* ----- locate library ----- */
function findLib(provided) {
  const candidates = [];
  if (provided) candidates.push(provided);
  // common names in repo (relative)
  candidates.push(path.join(__dirname, '..', 'lib', 'libmufiz.dylib'));
  candidates.push(path.join(__dirname, '..', 'lib', 'libmufiz.so'));
  candidates.push(path.join(__dirname, '..', 'lib', 'libmufiz.dll'));
  candidates.push(path.join(process.cwd(), 'lib', 'libmufiz.dylib'));
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

/* ----- known signatures (heuristic) ----- */
const KNOWN_SIGNATURES = {
  mufiz_init: { parameters: ['i32', 'i32', 'i32'], result: 'i32' },
  mufiz_interpret: { parameters: ['pointer'], result: 'i32' },
  interpret: { parameters: ['pointer'], result: 'pointer' },
  mufiz_free_cstring: { parameters: ['pointer'], result: 'void' },
  mufiz_strdup: { parameters: ['pointer'], result: 'pointer' },
  mufiz_deinit: { parameters: [], result: 'void' },
  deinit_wasm: { parameters: [], result: 'void' },
  init_wasm: { parameters: [], result: 'void' },
};

/* ----- Helpers ----- */
function normalizeSymbol(sym) {
  if (!sym) return sym;
  return sym.replace(/^_+/, '');
}

async function runNmOnLib(libPath) {
  try {
    const p = Bun.spawn({ cmd: ['nm', '-g', libPath], stdout: 'pipe', stderr: 'pipe' });
    const out = await new Response(p.stdout).text();
    return out.split('\n').map((l) => l.trim()).filter(Boolean);
  } catch (e) {
    // nm not available or failed
    return null;
  }
}

function parseNmLines(lines) {
  const syms = [];
  for (const l of lines) {
    // typical format: <addr> <type> <symbol>
    // fallback: take last token
    const parts = l.split(/\s+/);
    const s = parts[parts.length - 1];
    if (s) syms.push(s);
  }
  return syms;
}

/* ----- main ----- */
(async function main() {
  if (showHelp) {
    usage();
    return;
  }

  const libPath = findLib(libPathArg);
  if (!libPath) {
    console.error('Could not find libmufiz in repo (checked ./lib/*.). Use --lib /path/to/libmufiz.dylib if needed.');
    process.exit(2);
  }

  console.log('Inspecting native mufiz library at:', libPath);

  // Try to run nm to obtain symbol list
  let nmLines = await runNmOnLib(libPath);
  let rawSymbols = [];
  if (nmLines && nmLines.length) {
    rawSymbols = parseNmLines(nmLines);
    console.log(`nm reported ${rawSymbols.length} exported lines (showing first 40):`);
    console.log(rawSymbols.slice(0, 40).join('\n'));
  } else {
    console.log('`nm` output not available or empty; falling back to targeted probing.');
  }

  // Normalize symbols (strip leading underscores, etc)
  const normalizedSet = new Set(rawSymbols.map((s) => normalizeSymbol(s)));

  // Build bindings object only for symbols we know/care about and that appear exported.
  const bindings = {};
  for (const key of Object.keys(KNOWN_SIGNATURES)) {
    if (normalizedSet.size === 0) {
      // nm didn't work; we'll attempt to probe later (see below)
      continue;
    }
    if (normalizedSet.has(key)) {
      bindings[key] = KNOWN_SIGNATURES[key];
    }
  }

  let lib = null;
  if (Object.keys(bindings).length > 0) {
    try {
      lib = Bun.FFI.dlopen(libPath, bindings);
      console.log('Successfully bound symbols:', Object.keys(lib.symbols || {}).join(', '));
    } catch (e) {
      console.warn('Bun.FFI.dlopen with discovered symbols failed:', e && e.message ? e.message : e);
    }
  }

  // If we didn't get symbols via nm, or dlopen failed, try a conservative probe approach:
  if (!lib) {
    console.log('Attempting per-symbol probe using known candidate names...');
    const candidates = Object.keys(KNOWN_SIGNATURES);
    const found = [];
    for (const cand of candidates) {
      try {
        const map = {};
        map[cand] = KNOWN_SIGNATURES[cand];
        const prov = Bun.FFI.dlopen(libPath, map);
        // success: record symbol and close prov if possible
        found.push(cand);
        // Merge into bindings for final dlopen
        bindings[cand] = KNOWN_SIGNATURES[cand];
        // Attempt to close the short-lived handle if a close exists (not guaranteed)
        try {
          if (prov && typeof prov.close === 'function') prov.close();
        } catch (e) {
          // ignore
        }
      } catch (e) {
        // symbol not found or dlopen failed for this single-symbol probe
      }
    }

    if (Object.keys(bindings).length > 0) {
      try {
        lib = Bun.FFI.dlopen(libPath, bindings);
        console.log('Bound following symbols after probe:', Object.keys(lib.symbols || {}).join(', '));
      } catch (e) {
        console.warn('Final dlopen attempt failed:', e && e.message ? e.message : e);
      }
    } else {
      console.warn('Could not discover any known symbols by probing. There may still be symbols present under different names.');
    }
  }

  // Summary of discovered symbols (from nm if available)
  if (rawSymbols.length > 0) {
    const interesting = rawSymbols
      .map((s) => normalizeSymbol(s))
      .filter((s) => /mufiz|interpret|init|free|printf|print/i.test(s))
      .slice(0, 200);
    if (interesting.length > 0) {
      console.log('');
      console.log('Interesting symbols (filtered):');
      for (const s of interesting) console.log('  -', s);
    }
  }

  // If we have an FFI handle, try to call mufiz_init if present
  if (lib && lib.symbols) {
    if (typeof lib.symbols.mufiz_init === 'function') {
      try {
        const r = lib.symbols.mufiz_init(0, 0, 1);
        console.log('mufiz_init called, return:', r);
      } catch (e) {
        console.warn('mufiz_init call failed:', e && e.message ? e.message : e);
      }
    }
  } else {
    console.log('No FFI bindings present; cannot call functions directly from this process.');
  }

  // If user requested a call, attempt to call interpreter
  const codeToRun = callBase64 ? Buffer.from(callBase64, 'base64').toString('utf8') : callCode;
  if (typeof codeToRun === 'string' && codeToRun.length > 0) {
    console.log('');
    console.log('Attempting to call interpreter with code:');
    console.log('--------------------');
    console.log(codeToRun);
    console.log('--------------------');

    if (!lib || !lib.symbols) {
      console.error('No bound symbols available to call interpreter. Try running `nm -g <lib>` and ensure the library exports the expected symbols.');
      process.exit(3);
    }

    // Prefer 'interpret' (pointer-returning) if available, otherwise try 'mufiz_interpret'
    if (typeof lib.symbols.interpret === 'function') {
      try {
        const ptr = lib.symbols.interpret(Bun.FFI.CString(codeToRun));
        if (ptr) {
          try {
            const out = Bun.FFI.read(ptr);
            console.log('');
            console.log('[interpret returned string]');
            console.log(out);
            console.log('');
          } finally {
            if (typeof lib.symbols.mufiz_free_cstring === 'function') {
              try {
                lib.symbols.mufiz_free_cstring(ptr);
              } catch (e) {
                // ignore free errors
              }
            } else {
              console.warn('Note: interpret returned a pointer but no mufiz_free_cstring found; memory may be leaked in-process.');
            }
          }
        } else {
          console.log('interpret returned null/undefined (no output).');
        }
      } catch (e) {
        console.error('interpret call failed:', e && e.message ? e.message : e);
      }
    } else if (typeof lib.symbols.mufiz_interpret === 'function') {
      try {
        const rc = lib.symbols.mufiz_interpret(Bun.FFI.CString(codeToRun));
        console.log('mufiz_interpret returned:', rc);
      } catch (e) {
        console.error('mufiz_interpret call failed:', e && e.message ? e.message : e);
      }
    } else {
      console.error('No suitable interpret symbol found (tried `interpret` and `mufiz_interpret`). Use --inspect to view exported symbols or rebuild the library with exported functions.');
      process.exit(4);
    }
  } else {
    console.log('');
    console.log('No code provided to run. Use -c "<code>" to try calling the interpreter.');
  }

  console.log('');
  console.log('Done.');
})();
