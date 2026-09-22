import test from "node:test";
import assert from "node:assert/strict";
import { layout, overlaps, colorFor } from "../js/word_cloud.js";

// Approximate text width: 0.6em per character, like a bold sans-serif.
const measure = (text, size) => text.length * size * 0.6;

const words = [
  { text: "genetics", count: 17 },
  { text: "AI", count: 12 },
  { text: "counselling", count: 8 },
  { text: "family", count: 5 },
  { text: "uncertainty", count: 3 },
  { text: "testing", count: 2 },
  { text: "rare disease", count: 1 },
  { text: "future", count: 1 },
];

test("places every word inside the container without overlaps", () => {
  const placed = layout(words, 800, 450, { measure });
  assert.equal(placed.length, words.length);
  for (const p of placed) {
    assert.ok(p.x >= 0 && p.y >= 0, `${p.text} outside (negative)`);
    assert.ok(p.x + p.w <= 800 && p.y + p.h <= 450, `${p.text} outside (overflow)`);
  }
  for (let i = 0; i < placed.length; i++) {
    for (let j = i + 1; j < placed.length; j++) {
      assert.ok(!overlaps(placed[i], placed[j], 0), `${placed[i].text} overlaps ${placed[j].text}`);
    }
  }
});

test("the most frequent word is the largest and sits nearest the centre", () => {
  const placed = layout(words, 800, 450, { measure });
  const byText = Object.fromEntries(placed.map((p) => [p.text, p]));
  assert.ok(byText.genetics.size > byText.future.size);
  const dist = (p) => Math.hypot(p.x + p.w / 2 - 400, p.y + p.h / 2 - 225);
  assert.ok(dist(byText.genetics) <= dist(byText.future));
});

test("layout is deterministic", () => {
  const a = layout(words, 800, 450, { measure });
  const b = layout(words, 800, 450, { measure });
  assert.deepEqual(a, b);
});

test("a single word and an empty list work", () => {
  assert.deepEqual(layout([], 800, 450, { measure }), []);
  const [only] = layout([{ text: "solo", count: 1 }], 800, 450, { measure });
  assert.equal(only.text, "solo");
});

test("colours are stable per word", () => {
  assert.equal(colorFor("genetics"), colorFor("genetics"));
  assert.match(colorFor("genetics"), /^#[0-9a-f]{6}$/);
});
