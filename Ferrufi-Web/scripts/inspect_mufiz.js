#!/usr/bin/env node
// inspect_mufiz.js
//
// Quick helper to load the Emscripten-generated mufiz module (lib/mufiz.js + mufiz.wasm)
// and print top-level keys + wasm exports. Also offers a simple `--call` option to
// attempt a single `mufiz_interpret` invocation (useful to verify the interpreter symbol).
//
// Usage:
//   node scripts/inspect_mufiz.js            # prints exported keys
//   node scripts/inspect_mufiz.js -c 'code'  # attempts to call the interpreter with 'code'
//
// This is written to work with both Node and Bun runtimes.

"use strict";

(async function main() {
  const path = require("path");

  function usage() {
    console.log('Usage: inspect_mufiz.js [--call|-c "<code>"]');
    console.log(
      "  --call, -c    Attempt to call the detected interpret function with the given code string",
    );
    console.log("");
    console.log("Example:");
    console.log('  node scripts/inspect_mufiz.js -c "print(\\"hello\\")"');
  }

  // parse args
  const args = process.argv.slice(2);
  let callArg = null;
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === "--call" || a === "-c") {
      callArg = args[i + 1] || "";
      break;
    }
    if (a === "--help" || a === "-h") {
      usage();
      process.exit(0);
    }
  }

  // locate module factory relative to this script (scripts/inspect_mufiz.js -> ../lib/mufiz.js)
  const factoryPath = path.join(__dirname, "..", "lib", "mufiz_core_wasm.js");

  let ModuleFactory;
  try {
    // Use require so this runs under Node and Bun
    ModuleFactory = require(factoryPath);
  } catch (e) {
    console.error(`Failed to require factory at ${factoryPath}`);
    console.error(e && e.stack ? e.stack : e);
    process.exit(1);
  }

  // instantiate the module
  console.log(
    "Initializing module (this will load mufiz.wasm if necessary)...",
  );
  let mod;
  try {
    mod = await ModuleFactory({
      print: (...p) => console.log("[mufiz stdout]", ...p),
      printErr: (...p) => console.error("[mufiz stderr]", ...p),
      // locateFile: (f) => `./lib/${f}`, // uncomment if you want to override wasm path
    });
  } catch (e) {
    console.error("ModuleFactory failed to initialize the module:");
    console.error(e && e.stack ? e.stack : e);
    process.exit(1);
  }

  console.log("");
  console.log("Module loaded successfully.");
  console.log("");

  // helpers for inspection
  function listTopKeys() {
    try {
      const topKeys = Object.keys(mod).sort();
      console.log("Top-level keys:", topKeys.join(", ") || "(none)");
    } catch (e) {
      console.warn(
        "Could not list top-level keys:",
        e && e.message ? e.message : e,
      );
    }
    try {
      if (mod.wasmExports) {
        const wasmKeys = Object.keys(mod.wasmExports).sort();
        console.log("wasmExports keys:", wasmKeys.join(", ") || "(none)");
      } else {
        console.log("wasmExports: (none)");
      }
    } catch (e) {
      console.warn(
        "Could not list wasmExports keys:",
        e && e.message ? e.message : e,
      );
    }
  }

  listTopKeys();

  // quick candidate search
  const allKeys = new Set([
    ...Object.keys(mod || {}),
    ...(mod && mod.wasmExports ? Object.keys(mod.wasmExports) : []),
  ]);
  const candidates = Array.from(allKeys).filter((k) =>
    /mufiz|interpret/i.test(k),
  );
  if (candidates.length) {
    console.log(
      "Candidate keys that look related to mufiz/interpret:",
      candidates.join(", "),
    );
  } else {
    console.log(
      'No obvious candidate keys containing "mufiz" or "interpret" were found.',
    );
  }

  // detection strategy for the interpret function
  function findInterpret() {
    // 1) cwrap('mufiz_interpret')
    if (mod.cwrap) {
      try {
        const wrapped = mod.cwrap("mufiz_interpret", "number", ["string"]);
        if (typeof wrapped === "function")
          return { type: "cwrap", fn: wrapped, name: "mufiz_interpret" };
      } catch (e) {
        // ignore
      }
    }

    // 2) Module-underscored direct symbol (common for Emscripten builds)
    if (typeof mod._mufiz_interpret === "function") {
      return {
        type: "module_underscore",
        fn: mod._mufiz_interpret,
        name: "_mufiz_interpret",
      };
    }

    // 3) direct modul-level name (less common)
    if (typeof mod.mufiz_interpret === "function") {
      return {
        type: "module",
        fn: mod.mufiz_interpret,
        name: "mufiz_interpret",
      };
    }

    // 4) raw wasm export
    if (
      mod.wasmExports &&
      typeof mod.wasmExports.mufiz_interpret === "function"
    ) {
      return {
        type: "wasmExports",
        fn: mod.wasmExports.mufiz_interpret,
        name: "mufiz_interpret",
      };
    }

    // 5) heuristic: find anything with interpret in the name
    const interpretKey =
      Array.from(allKeys).find((k) => /mufiz.*interpret/i.test(k)) ||
      Array.from(allKeys).find((k) => /interpret/i.test(k));
    if (interpretKey) {
      const fn =
        typeof mod[interpretKey] === "function"
          ? mod[interpretKey]
          : mod.wasmExports &&
              typeof mod.wasmExports[interpretKey] === "function"
            ? mod.wasmExports[interpretKey]
            : null;
      if (fn) {
        return { type: "discovered", fn, name: interpretKey };
      }
    }

    return null;
  }

  const interp = findInterpret();
  if (!interp) {
    console.log("");
    console.log("INTERPRET FUNCTION NOT FOUND.");
    console.log(
      "If you expected mufiz_interpret to be exported, check how the wasm was built (were the C symbols exported?)",
    );
    console.log(
      "You can also use the Inspect button in the UI (or this script) to print available keys and wasm exports.",
    );
    console.log("");
    if (!callArg) process.exit(0);
  } else {
    console.log("");
    console.log(
      `Found interpret function: name='${interp.name}' via ${interp.type}`,
    );
  }

  // If user requested a sample call, attempt it
  if (callArg != null) {
    console.log("");
    console.log(
      `Attempting to call interpreter with provided code: ${JSON.stringify(callArg)}`,
    );

    try {
      if (interp.type === "cwrap") {
        // wrapped function expects a JS string
        const r = interp.fn(callArg);
        console.log("interpret returned:", r);
      } else {
        // allocate a C string and call
        let ptr = null;
        if (typeof mod.allocateUTF8 === "function") {
          ptr = mod.allocateUTF8(callArg);
          try {
            const r = interp.fn(ptr);
            console.log("interpret returned:", r);
          } finally {
            // allocateUTF8 may not provide a free; it's okay for a short-lived test.
          }
        } else if (mod._malloc && mod.lengthBytesUTF8 && mod.stringToUTF8) {
          const len = mod.lengthBytesUTF8(callArg) + 1;
          ptr = mod._malloc(len);
          try {
            mod.stringToUTF8(callArg, ptr, len);
            const r = interp.fn(ptr);
            console.log("interpret returned:", r);
          } finally {
            if (mod._free) mod._free(ptr);
          }
        } else {
          console.error(
            "Unable to allocate a C string to pass to the function: missing allocateUTF8 or (_malloc + stringToUTF8).",
          );
        }
      }
    } catch (e) {
      console.error(
        "Call to interpret threw an exception:",
        e && e.stack ? e.stack : e,
      );
    }
  }

  console.log("");
  console.log("Inspection complete.");
  process.exit(0);
})();
