// Word cloud layout hook.
//
// The element carries `data-words` (JSON `[{text, count}]`). Words are placed
// on an archimedean spiral around the centre, largest first, with a simple
// rectangle collision test. Text is measured on a canvas so the layout does
// not depend on the DOM. Words keep their colour and (mostly) their position
// between updates, so a live cloud grows instead of jumping around.
//
// Attributes:
//   data-words       JSON list of {text, count}
//   data-min-size    minimum font size in px (optional)
//   data-max-size    maximum font size in px (optional)
//   data-font        font family (optional)
//   data-empty       text shown while there are no words (optional)

const FONT = "Inter, 'Helvetica Neue', Arial, sans-serif";
const PALETTE = [
  "#f5f5f5",
  "#a5b4fc",
  "#f9a8d4",
  "#86efac",
  "#fcd34d",
  "#93c5fd",
  "#fda4af",
  "#67e8f9",
  "#c4b5fd",
  "#fdba74",
];

function hash(text) {
  let h = 2166136261;
  for (let i = 0; i < text.length; i++) {
    h ^= text.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function parseWords(el) {
  try {
    const words = JSON.parse(el.dataset.words || "[]");
    return Array.isArray(words) ? words : [];
  } catch (_e) {
    return [];
  }
}

function sizeFor(count, minCount, maxCount, minSize, maxSize) {
  if (maxCount === minCount) return Math.round((minSize + maxSize) / 2);
  const ratio = Math.sqrt((count - minCount) / (maxCount - minCount));
  return Math.round(minSize + ratio * (maxSize - minSize));
}

function canvasMeasure(text, size, font) {
  const canvas =
    canvasMeasure._canvas || (canvasMeasure._canvas = document.createElement("canvas"));
  const ctx = canvas.getContext("2d");
  ctx.font = `700 ${size}px ${font}`;
  return ctx.measureText(text).width;
}

export function overlaps(a, b, pad) {
  return !(
    a.x + a.w + pad <= b.x ||
    b.x + b.w + pad <= a.x ||
    a.y + a.h + pad <= b.y ||
    b.y + b.h + pad <= a.y
  );
}

export function layout(words, width, height, opts = {}) {
  if (!words.length) return [];
  const font = opts.font || FONT;
  const minSize = opts.minSize || Math.max(16, Math.round(height / 14));
  const maxSize = opts.maxSize || Math.max(minSize + 8, Math.round(height / 4));
  const pad = Math.max(6, Math.round(minSize * 0.35));

  const measure = opts.measure || canvasMeasure;

  const counts = words.map((w) => w.count);
  const minCount = Math.min(...counts);
  const maxCount = Math.max(...counts);

  const sorted = [...words].sort((a, b) => b.count - a.count || a.text.localeCompare(b.text));
  const placed = [];
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
      const step = 0.35;
      const a = Math.max(2, size / 10);

      for (let t = 0; t < 4000; t += step) {
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

export function colorFor(text) {
  return PALETTE[hash(text) % PALETTE.length];
}

const WordCloud = {
  mounted() {
    this.nodes = new Map();
    this.render = this.render.bind(this);
    this.observer = new ResizeObserver(() => this.schedule());
    this.observer.observe(this.el);
    this.render();
  },

  updated() {
    this.render();
  },

  destroyed() {
    if (this.observer) this.observer.disconnect();
    if (this.raf) cancelAnimationFrame(this.raf);
  },

  schedule() {
    if (this.raf) cancelAnimationFrame(this.raf);
    this.raf = requestAnimationFrame(this.render);
  },

  render() {
    const el = this.el;
    const width = el.clientWidth;
    const height = el.clientHeight;
    if (!width || !height) return;

    const words = parseWords(el);
    const font = el.dataset.font || FONT;
    const minSize = el.dataset.minSize ? parseInt(el.dataset.minSize, 10) : undefined;
    const maxSize = el.dataset.maxSize ? parseInt(el.dataset.maxSize, 10) : undefined;

    let empty = el.querySelector("[data-word-cloud-empty]");
    if (!empty) {
      empty = document.createElement("div");
      empty.setAttribute("data-word-cloud-empty", "");
      empty.className =
        "absolute inset-0 flex items-center justify-center text-center opacity-60 pointer-events-none";
      el.appendChild(empty);
    }
    empty.textContent = el.dataset.empty || "";
    empty.style.display = words.length ? "none" : "flex";

    const placed = layout(words, width, height, { font, minSize, maxSize });
    const seen = new Set();

    for (const p of placed) {
      seen.add(p.text);
      let node = this.nodes.get(p.text);
      if (!node) {
        node = document.createElement("span");
        node.className = "word-cloud-word";
        node.style.position = "absolute";
        node.style.whiteSpace = "nowrap";
        node.style.fontWeight = "700";
        node.style.lineHeight = "1.15";
        node.style.fontFamily = font;
        node.style.color = colorFor(p.text);
        node.style.transition =
          "transform 600ms cubic-bezier(0.22, 1, 0.36, 1), font-size 600ms ease, opacity 300ms ease";
        node.style.transform = `translate(${width / 2}px, ${height / 2}px) scale(0.2)`;
        node.style.opacity = "0";
        node.textContent = p.text;
        el.appendChild(node);
        this.nodes.set(p.text, node);
        // force a frame so the transition plays
        void node.offsetWidth;
      }
      node.title = `${p.text} (${p.count})`;
      node.dataset.count = p.count;
      node.style.fontSize = `${p.size}px`;
      node.style.transform = `translate(${Math.round(p.x)}px, ${Math.round(p.y)}px) scale(1)`;
      node.style.opacity = "1";
    }

    for (const [text, node] of this.nodes) {
      if (!seen.has(text)) {
        node.style.opacity = "0";
        node.style.transform += " scale(0.2)";
        setTimeout(() => node.remove(), 320);
        this.nodes.delete(text);
      }
    }
  },
};

export default WordCloud;
