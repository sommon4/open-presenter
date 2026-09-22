// Renders one interaction inside the slide. Everything goes through
// textContent / createElement: attendee text is never injected as HTML.

import QRCode from "qrcode";
import type { ApiEvent, Interaction, Post } from "./api";
import { colorFor, layout } from "./word_cloud_layout";

export function el<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  className?: string,
  text?: string,
): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

export function clear(node: HTMLElement): void {
  while (node.firstChild) node.removeChild(node.firstChild);
}

export interface RenderContext {
  root: HTMLElement;
  event: ApiEvent | null;
  showJoin: boolean;
}

export async function renderJoinPanel(container: HTMLElement, event: ApiEvent, big = false) {
  const panel = el("div", big ? "join join-big" : "join");
  const canvas = el("canvas", "join-qr");
  try {
    await QRCode.toCanvas(canvas, event.join_url, { width: big ? 240 : 96, margin: 1 });
  } catch (_e) {
    // QR generation failed; the URL text is still shown
  }
  panel.appendChild(canvas);
  const text = el("div", "join-text");
  text.appendChild(el("div", "join-label", big ? "Scan to interact" : "Scan to answer"));
  text.appendChild(el("div", "join-url", event.join_url.replace(/^https?:\/\//, "")));
  text.appendChild(el("div", "join-code", event.join_code));
  panel.appendChild(text);
  container.appendChild(panel);
}

export function renderHeader(container: HTMLElement, interaction: Interaction) {
  const header = el("div", "header");
  header.appendChild(el("h1", "title", interaction.title ?? ""));
  if (!interaction.enabled) header.appendChild(el("span", "badge badge-muted", "not active"));
  container.appendChild(header);
}

export function renderPoll(container: HTMLElement, interaction: Interaction) {
  const options = interaction.results.options ?? [];
  const list = el("div", "poll");
  for (const o of options) {
    const row = el("div", "poll-row");
    const bar = el("div", "poll-bar");
    bar.style.width = `${Math.max(0, Math.min(100, o.percentage))}%`;
    row.appendChild(bar);
    row.appendChild(el("span", "poll-label", o.content));
    row.appendChild(el("span", "poll-value", `${Math.round(o.percentage)}% (${o.vote_count})`));
    list.appendChild(row);
  }
  container.appendChild(list);
  container.appendChild(el("p", "muted footer", `${interaction.results.total_votes ?? 0} votes`));
}

export function renderWordCloud(container: HTMLElement, interaction: Interaction) {
  const words = (interaction.results.words ?? []).map((w) => ({ text: w.text, count: w.count }));
  const box = el("div", "cloud");
  container.appendChild(box);
  const draw = () => {
    clear(box);
    const width = box.clientWidth;
    const height = box.clientHeight;
    if (!width || !height) return;
    if (!words.length) {
      box.appendChild(el("div", "cloud-empty muted", "Waiting for answers…"));
      return;
    }
    for (const p of layout(words, width, height)) {
      const span = el("span", "cloud-word", p.text);
      span.style.left = `${p.x}px`;
      span.style.top = `${p.y}px`;
      span.style.fontSize = `${p.size}px`;
      span.style.color = colorFor(p.text);
      span.title = `${p.text} (${p.count})`;
      box.appendChild(span);
    }
  };
  requestAnimationFrame(draw);
  new ResizeObserver(() => draw()).observe(box);
  container.appendChild(el("p", "muted footer", `${interaction.results.total ?? 0} answers`));
}

export function renderOpenEnded(container: HTMLElement, interaction: Interaction) {
  const responses = interaction.results.responses ?? [];
  const grid = el("div", "cards");
  if (!responses.length) grid.appendChild(el("div", "muted cloud-empty", "Waiting for responses…"));
  for (const r of responses) {
    const card = el("div", "card");
    card.appendChild(el("p", "card-text", r.text));
    if (interaction.results.voting_enabled) card.appendChild(el("p", "card-votes", `👍 ${r.vote_count}`));
    grid.appendChild(card);
  }
  container.appendChild(grid);
  if (interaction.results.auto_scroll) requestAnimationFrame(() => (grid.scrollTop = grid.scrollHeight));
  container.appendChild(el("p", "muted footer", `${interaction.results.total ?? 0} responses`));
}

export function renderQuiz(container: HTMLElement, interaction: Interaction) {
  const questions = interaction.results.questions ?? [];
  const wrap = el("div", "quiz");
  questions.forEach((q, i) => {
    const block = el("div", "quiz-question");
    block.appendChild(el("h2", "quiz-title", `${i + 1}. ${q.content}`));
    for (const o of q.options) {
      const row = el("div", o.is_correct ? "poll-row correct" : "poll-row");
      const bar = el("div", "poll-bar");
      bar.style.width = `${Math.max(0, Math.min(100, o.percentage))}%`;
      row.appendChild(bar);
      row.appendChild(el("span", "poll-label", (o.is_correct ? "✓ " : "") + o.content));
      row.appendChild(el("span", "poll-value", `${Math.round(o.percentage)}% (${o.response_count})`));
      block.appendChild(row);
    }
    wrap.appendChild(block);
  });
  container.appendChild(wrap);
}

export function renderForm(container: HTMLElement, interaction: Interaction) {
  container.appendChild(el("p", "big-number", String(interaction.results.submit_count ?? 0)));
  container.appendChild(el("p", "muted", "submissions"));
}

export function renderEmbed(container: HTMLElement, interaction: Interaction) {
  container.appendChild(el("p", "muted", `Web content (${interaction.results.provider ?? "custom"}) is shown on the browser presenter.`));
}

export function renderPosts(container: HTMLElement, posts: Post[]) {
  const list = el("div", "cards");
  if (!posts.length) list.appendChild(el("div", "muted cloud-empty", "No questions yet"));
  for (const p of posts) {
    const card = el("div", p.pinned ? "card pinned" : "card");
    card.appendChild(el("p", "card-text", p.body));
    const meta = el("p", "card-votes");
    meta.textContent = `${p.name ?? "Anonymous"} · 👍 ${p.like_count}`;
    card.appendChild(meta);
    list.appendChild(card);
  }
  container.appendChild(list);
}

export function renderInteraction(container: HTMLElement, interaction: Interaction) {
  renderHeader(container, interaction);
  const body = el("div", "body");
  container.appendChild(body);
  switch (interaction.type) {
    case "poll":
      renderPoll(body, interaction);
      break;
    case "word_cloud":
      renderWordCloud(body, interaction);
      break;
    case "open_ended":
      renderOpenEnded(body, interaction);
      break;
    case "quiz":
      renderQuiz(body, interaction);
      break;
    case "form":
      renderForm(body, interaction);
      break;
    case "embed":
      renderEmbed(body, interaction);
      break;
  }
}
