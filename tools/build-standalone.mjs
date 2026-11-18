#!/usr/bin/env node
// Builds the single-file standalone app (index.html) from
// inst/standalone/template.html. Every line of the form
//   @@include <path relative to inst/>
// is replaced by that file's lines. The output is byte-identical to
// aconteceR::build_standalone() in R/standalone.R (a test checks this).
//
//   node tools/build-standalone.mjs            # writes ./index.html
//   node tools/build-standalone.mjs out.html
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const inst = join(root, "inst");
const out = process.argv[2] ? resolve(process.argv[2]) : join(root, "index.html");

// Sequences that would end the surrounding <script>, <style> or <!-- --> early.
const FORBIDDEN = /<\/script|<\/style|<!--|-->/i;

const readLines = (file) => {
  const parts = readFileSync(file, "utf8").replace(/^\uFEFF/, "").split(/\r?\n/);
  if (parts.length && parts[parts.length - 1] === "") parts.pop();
  return parts;
};

const result = [];
for (const line of readLines(join(inst, "standalone", "template.html"))) {
  const m = /^@@include (\S+)$/.exec(line.trim());
  if (!m) { result.push(line); continue; }
  const content = readLines(join(inst, m[1]));
  const bad = content.find((l) => FORBIDDEN.test(l));
  if (bad !== undefined) {
    throw new Error(`${m[1]} contains a sequence that would break the inlined HTML: ${bad.slice(0, 80)}`);
  }
  result.push(...content);
}
writeFileSync(out, result.join("\n") + "\n");
console.log(`Wrote ${out} (${(Buffer.byteLength(result.join("\n")) / 1024).toFixed(0)} KB)`);
