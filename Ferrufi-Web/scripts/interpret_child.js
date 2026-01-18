#!/usr/bin/env bun
'use strict';

/**
 * scripts/interpret_child.js
 *
 * Bun child runner that loads the native mufiz library via bun:ffi and runs a single
 * piece of source code, returning/printing any output produced by the runtime.
 *
 * Input:
 *  - First CLI argument (base64-encoded source) OR
 *  - Environment variable MUFIZ_CODE (raw source) OR
 *  - Environment variable MUFIZ_CODE_B64 (base64 source) OR
 *  - Piped stdin (raw source)
 *
 * Output (stdout):
 *  - A JSON "start" marker line
 *  - The raw output the mufiz runtime prints (if any)
 *  - A JSON "end" marker line which includes the return code (if available)
 *
 * This makes it straightforward for a parent process to spawn this script, capture
 * stdout/stderr and extract the interpreter output between the markers.
 *
 * Example:
 *   bun scripts/interpret_child.js $(node -e "console.log(Buffer.from('print(\"hi\")').toString('base64'))")
 */

const fs = require('fs');
const path = require('path');

function findLib() {
  const candidates = [
    path.join(__dirname, '..', 'lib', 'libmufiz.dylib'),
    path.join(__dirname, '..', 'lib', 'libmufiz.so'),
    path.join(__dirname, '..', 'lib', 'libmufiz.dll'),
  ];
  for (const p of candidates) {
    try {
      if (fs.existsSync(p)) return p;
    } catch (e) {
      // ignore
    }
  }
  // fallback to relative path (best-effort)
  return path.join(__dirname, '..', 'lib', 'libmufiz.dylib');
}

function readStdinSync() {
  try {
    // Synchronously read all stdin if anything is piped
    const stat = fs.fstatSync(0);
    if (stat && stat.size > 0) {
      return fs.readFileSync(0, 'utf8');
    }
    // If size is 0, still attempt to read (some pipes don't report size)
    return fs.readFileSync(0, 'utf8');
  } catch (e) {
    return '';
  }
}

function decodePossibleBase64(s) {
  // Heuristic: if the string contains non-printable characters or looks like base64
  try {
    // try decode and re-encode; if matches, consider it base64
    const buf = Buffer.from(s, 'base64');
    if (buf.toString('base64').replace(/=+$/, '') === s.replace(/=+$/, '')) {
      return buf.toString('utf8');
    }
  } catch (e) {
    // ignore
  }
  return s;
}

(async function main() {
  const libPath = findLib();

  let lib;
  try {
    lib = Bun.FFI.dlopen(libPath, {
      // Common useful mufiz entry points - adjust as necessary for your build
      mufiz_init: { parameters: ['i32', 'i32', 'i32'], result: 'i32' },
      mufiz_interpret: { parameters: ['pointer'], result: 'i32' },
      // Some builds expose an 'interpret' that returns a cstring pointer;
      // binding this is optional and may or may not exist depending on how the
      // native library was built. We try to bind it only if available.
      // (note: if the symbol is absent, dlopen will typically throw - so keep
      //  the set conservative)
      mufiz_free_cstring: { parameters: ['pointer'], result: 'void' },
    });
  } catch (e) {
    // Try an alternative with the 'interpret' symbol included (some builds provide it)
    try {
      lib = Bun.FFI.dlopen(libPath, {
        mufiz_init: { parameters: ['i32', 'i32', 'i32'], result: 'i32' },
        mufiz_interpret: { parameters: ['pointer'], result: 'i32' },
        interpret: { parameters: ['pointer'], result: 'pointer' },
        mufiz_free_cstring: { parameters: ['pointer'], result: 'void' },
      });
    } catch (err) {
      console.error(
        JSON.stringify({
          mufiz: 'error',
          message: `Failed to load native library '${libPath}': ${err && err.message ? err.message : String(err)}`,
        }),
      );
      process.exit(2);
    }
  }

  // Determine source input (priority: CLI arg base64 -> MUFIZ_CODE -> MUFIZ_CODE_B64 -> stdin)
  const argv = process.argv.slice(2);
  let source = '';

  if (argv.length > 0 && argv[0]) {
    // Expect base64 encoded payload (safer for arbitrary code on command line)
    try {
      source = Buffer.from(argv[0], 'base64').toString('utf8');
    } catch (e) {
      // Fallback: treat as raw
      source = argv[0];
    }
  } else if (process.env.MUFIZ_CODE) {
    source = process.env.MUFIZ_CODE;
  } else if (process.env.MUFIZ_CODE_B64) {
    try {
      source = Buffer.from(process.env.MUFIZ_CODE_B64, 'base64').toString('utf8');
    } catch (e) {
      source = process.env.MUFIZ_CODE_B64;
    }
  } else {
    source = readStdinSync();
  }

  // fallback: trim BOM, ensure string
  if (!source) source = '';

  const runId = `${process.pid}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;

  // Marker helpers (JSON lines for robust parsing)
  const markerStart = JSON.stringify({ mufiz: 'start', id: runId });
  const markerEndBase = (rc) => JSON.stringify({ mufiz: 'end', id: runId, rc });

  // Print start marker
  console.log(markerStart);

  // Call init if available
  try {
    if (lib && lib.symbols && typeof lib.symbols.mufiz_init === 'function') {
      try {
        lib.symbols.mufiz_init(0, 0, 1);
      } catch (e) {
        // ignore init failure but report it
        console.error(JSON.stringify({ mufiz: 'init_error', id: runId, message: String(e && e.message ? e.message : e) }));
      }
    }
  } catch (e) {
    // ignore
  }

  // Prepare C string pointer for source (Bun.FFI.CString is convenient)
  let srcPtr = null;
  try {
    srcPtr = Bun.FFI.CString(source);
  } catch (e) {
    // If CString fails, still continue by trying to pass 0 or empty string
    srcPtr = Bun.FFI.CString('');
  }

  // Execution: try to use an 'interpret' returning a pointer (preferred if present),
  // otherwise fall back to 'mufiz_interpret' (which often prints to stdout & returns int).
  let returnCode = null;
  try {
    if (lib.symbols && typeof lib.symbols.interpret === 'function') {
      // This branch expects a pointer return (char*) which we can read and print
      try {
        const resPtr = lib.symbols.interpret(srcPtr);
        if (resPtr) {
          try {
            const out = Bun.FFI.read(resPtr);
            if (out) {
              // Print raw interpreter output between markers
              process.stdout.write(out + '\n');
            }
          } finally {
            if (lib.symbols.mufiz_free_cstring) {
              try {
                lib.symbols.mufiz_free_cstring(resPtr);
              } catch (_) {}
            }
          }
        }
        // Some builds may return a pointer but also set a status elsewhere; we set rc to 0 to indicate success
        returnCode = 0;
      } catch (e) {
        console.error(JSON.stringify({ mufiz: 'error', id: runId, message: String(e && e.message ? e.message : e) }));
        returnCode = 1;
      }
    } else if (lib.symbols && typeof lib.symbols.mufiz_interpret === 'function') {
      // Fallback: call mufiz_interpret (commonly returns int and prints to stdout/stderr)
      try {
        const rc = lib.symbols.mufiz_interpret(srcPtr);
        // rc may be undefined for some builds - normalize to integer when possible
        returnCode = typeof rc === 'number' ? rc : 0;
      } catch (e) {
        console.error(JSON.stringify({ mufiz: 'error', id: runId, message: String(e && e.message ? e.message : e) }));
        returnCode = 1;
      }
    } else {
      console.error(JSON.stringify({ mufiz: 'error', id: runId, message: 'No suitable interpret symbol found on library.' }));
      returnCode = 2;
    }
  } catch (e) {
    console.error(JSON.stringify({ mufiz: 'error', id: runId, message: String(e && e.message ? e.message : e) }));
    returnCode = 1;
  } finally {
    // Print end marker with return code
    console.log(markerEndBase(returnCode === null ? 0 : returnCode));

    // exit explicitly with the return code so parent can detect abnormal termination.
    try {
      process.exit(typeof returnCode === 'number' ? returnCode : 0);
    } catch (e) {
      // if exit throws (weird), just allow process to terminate naturally
    }
  }
})();
