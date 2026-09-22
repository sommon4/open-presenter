import test from "node:test";
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

// Transpile the TS module with esbuild (a vite dependency) for a plain node test.
const dir = mkdtempSync(join(tmpdir(), "wc-"));
const out = join(dir, "layout.mjs");
execSync(`npx esbuild src/word_cloud_layout.ts --format=esm --outfile=${out}`, { stdio: "ignore" });
const { layout, overlaps } = await import(out);

const measure = (text, size) => text.length * size * 0.6;
const words = [
  { text: "genetics", count: 17 },
  { text: "AI", count: 12 },
  { text: "counselling", count: 8 },
  { text: "family", count: 5 },
  { text: "uncertainty", count: 3 },
  { text: "rare disease", count: 1 },
];

test("places all words inside the box without overlap", () => {
  const placed = layout(words, 640, 360, { measure });
  assert.equal(placed.length, words.length);
  for (const p of placed) {
    assert.ok(p.x >= 0 && p.y >= 0 && p.x + p.w <= 640 && p.y + p.h <= 360, p.text);
  }
  for (let i = 0; i < placed.length; i++)
    for (let j = i + 1; j < placed.length; j++)
      assert.ok(!overlaps(placed[i], placed[j], 0), `${placed[i].text} / ${placed[j].text}`);
});

test("is deterministic", () => {
  assert.deepEqual(layout(words, 640, 360, { measure }), layout(words, 640, 360, { measure }));
});
