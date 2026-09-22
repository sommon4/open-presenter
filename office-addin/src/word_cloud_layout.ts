// Spiral word cloud layout. Same algorithm as assets/js/word_cloud.js in the
// Phoenix app, so PowerPoint and the browser presenter look alike.

export interface CloudWord {
  text: string;
  count: number;
}

export interface PlacedWord extends CloudWord {
  x: number;
  y: number;
  w: number;
  h: number;
  size: number;
}

export type Measure = (text: string, size: number, font: string) => number;

export const CLOUD_FONT = "'Segoe UI', Inter, 'Helvetica Neue', Arial, sans-serif";

const PALETTE = [
  "#1f2937",
  "#4f46e5",
  "#db2777",
  "#059669",
  "#d97706",
  "#2563eb",
  "#dc2626",
  "#0891b2",
  "#7c3aed",
  "#ea580c",
];

export function hash(text: string): number {
  let h = 2166136261;
  for (let i = 0; i < text.length; i++) {
    h ^= text.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

export function colorFor(text: string): string {
  return PALETTE[hash(text) % PALETTE.length];
}

function sizeFor(count: number, minCount: number, maxCount: number, minSize: number, maxSize: number) {
  if (maxCount === minCount) return Math.round((minSize + maxSize) / 2);
  const ratio = Math.sqrt((count - minCount) / (maxCount - minCount));
  return Math.round(minSize + ratio * (maxSize - minSize));
}

export function overlaps(a: PlacedWord, b: { x: number; y: number; w: number; h: number }, pad: number) {
  return !(a.x + a.w + pad <= b.x || b.x + b.w + pad <= a.x || a.y + a.h + pad <= b.y || b.y + b.h + pad <= a.y);
}

let canvas: HTMLCanvasElement | null = null;

export const canvasMeasure: Measure = (text, size, font) => {
  if (!canvas) canvas = document.createElement("canvas");
  const ctx = canvas.getContext("2d")!;
  ctx.font = `700 ${size}px ${font}`;
  return ctx.measureText(text).width;
};

export function layout(
  words: CloudWord[],
  width: number,
  height: number,
  opts: { font?: string; minSize?: number; maxSize?: number; measure?: Measure } = {},
): PlacedWord[] {
  if (!words.length) return [];
  const font = opts.font || CLOUD_FONT;
  const minSize = opts.minSize || Math.max(14, Math.round(height / 14));
  const maxSize = opts.maxSize || Math.max(minSize + 8, Math.round(height / 4));
  const measure = opts.measure || canvasMeasure;
  const pad = Math.max(6, Math.round(minSize * 0.35));

  const counts = words.map((w) => w.count);
  const minCount = Math.min(...counts);
  const maxCount = Math.max(...counts);
  const sorted = [...words].sort((a, b) => b.count - a.count || a.text.localeCompare(b.text));
  const placed: PlacedWord[] = [];
  const cx = width / 2;
  const cy = height / 2;

  for (const word of sorted) {
    let size = sizeFor(word.count, minCount, maxCount, minSize, maxSize);
    let done = false;
    for (let attempt = 0; attempt < 4 && !done; attempt++) {
      const w = Math.ceil(measure(word.text, size, font)) + 2;
      const h = Math.ceil(size * 1.15);
      if (w > width || h > height) {
        size = Math.max(minSize, Math.round(size * 0.8));
        if (size === minSize && attempt > 0) break;
        continue;
      }
      const start = (hash(word.text) % 360) * (Math.PI / 180);
      const a = Math.max(2, size / 10);
      for (let t = 0; t < 4000; t += 0.35) {
        const r = a * t * 0.12;
        const x = cx + r * Math.cos(t + start) - w / 2;
        const y = cy + (r * Math.sin(t + start) * height) / width - h / 2;
        if (x < 0 || y < 0 || x + w > width || y + h > height) {
          if (r > Math.max(width, height)) break;
          continue;
        }
        const rect = { x, y, w, h };
        if (!placed.some((p) => overlaps(p, rect, pad))) {
          placed.push({ ...rect, text: word.text, count: word.count, size });
          done = true;
          break;
        }
      }
      if (!done) size = Math.max(minSize, Math.round(size * 0.85));
    }
  }
  return placed;
}
