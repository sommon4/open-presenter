// Entry point of the PowerPoint content add-in.
//
// Flow:  Office.onReady → load settings → (setup → event → interaction) → live
//
// "Live" connects to the Office channel and re-renders on every push. The
// mapping slide → interaction is stored per add-in instance (settings.ts).

import { Api, ApiError, type ApiEvent, type Interaction, type Post } from "./api";
import { Realtime, type ConnectionState } from "./realtime";
import { clear, el, renderInteraction, renderJoinPanel, renderPosts } from "./renderer";
import { defaultServerUrl, loadConfig, saveConfig, type AddinConfig } from "./settings";

const JOIN_SCREEN = "join_screen";
const QA = "qa";

class App {
  private root = document.getElementById("app")!;
  private config: AddinConfig = loadConfig();
  private api: Api | null = null;
  private realtime: Realtime | null = null;
  private event: ApiEvent | null = null;
  private interaction: Interaction | null = null;
  private posts: Post[] = [];
  private connection: ConnectionState = "closed";
  private socketToken: string | null = null;
  private socketPath = "/office/socket";

  async start() {
    this.config = loadConfig();
    if (!this.config.token) return this.showSetup();
    try {
      await this.connectApi();
    } catch (e) {
      return this.showSetup(errorMessage(e));
    }
    if (!this.config.eventId) return this.showEvents();
    if (!this.config.interactionId) return this.showInteractions();
    return this.showLive();
  }

  private async connectApi() {
    this.api = new Api(this.config.serverUrl, this.config.token);
    const auth = await this.api.auth();
    this.socketToken = auth.socket_token;
    this.socketPath = auth.socket_path;
  }

  // ---------- screens ----------

  private screen(title: string): HTMLElement {
    this.realtime?.disconnect();
    this.realtime = null;
    clear(this.root);
    const screen = el("div", "screen setup");
    screen.appendChild(el("h1", "setup-title", title));
    this.root.appendChild(screen);
    return screen;
  }

  private showSetup(error?: string) {
    const screen = this.screen("Connect to Open Presenter");
    screen.appendChild(
      el("p", "muted", "Generate a token in Open Presenter under Settings → PowerPoint add-in, then paste it here."),
    );
    const form = el("form", "form");
    const server = input("Server URL", this.config.serverUrl || defaultServerUrl(), "url");
    const token = input("Access token", this.config.token, "password");
    form.appendChild(server.wrap);
    form.appendChild(token.wrap);
    const err = el("p", "error", error ?? "");
    form.appendChild(err);
    form.appendChild(button("Connect", "primary"));
    form.addEventListener("submit", async (e) => {
      e.preventDefault();
      err.textContent = "";
      this.config = {
        ...this.config,
        serverUrl: server.field.value.trim().replace(/\/+$/, ""),
        token: token.field.value.trim(),
        eventId: null,
        interactionId: null,
      };
      try {
        await this.connectApi();
        await saveConfig(this.config);
        this.showEvents();
      } catch (e2) {
        err.textContent = errorMessage(e2);
      }
    });
    screen.appendChild(form);
  }

  private async showEvents() {
    const screen = this.screen("Select an event");
    const list = el("div", "list");
    screen.appendChild(list);
    screen.appendChild(linkButton("Change server or token", () => this.showSetup()));
    try {
      const events = await this.api!.events();
      if (!events.length) list.appendChild(el("p", "muted", "No events yet. Create one in Open Presenter first."));
      for (const ev of events) {
        const item = el("button", "list-item");
        item.type = "button";
        item.appendChild(el("span", "list-title", ev.name));
        item.appendChild(el("span", "list-sub", `Code ${ev.join_code} · ${ev.slides} slides`));
        item.addEventListener("click", async () => {
          this.config = { ...this.config, eventId: ev.id, eventName: ev.name, interactionId: null };
          this.event = ev;
          await saveConfig(this.config);
          this.showInteractions();
        });
        list.appendChild(item);
      }
    } catch (e) {
      list.appendChild(el("p", "error", errorMessage(e)));
    }
  }

  private async showInteractions() {
    const screen = this.screen(`Select an interaction`);
    screen.appendChild(el("p", "muted", this.config.eventName ?? ""));
    const list = el("div", "list");
    screen.appendChild(list);
    screen.appendChild(linkButton("Choose another event", () => this.showEvents()));
    const pick = async (id: string) => {
      this.config = { ...this.config, interactionId: id };
      await saveConfig(this.config);
      this.showLive();
    };
    const special = (id: string, title: string, sub: string) => {
      const item = el("button", "list-item special");
      item.type = "button";
      item.appendChild(el("span", "list-title", title));
      item.appendChild(el("span", "list-sub", sub));
      item.addEventListener("click", () => pick(id));
      list.appendChild(item);
    };
    special(JOIN_SCREEN, "Join screen", "QR code and join code");
    special(QA, "Questions (Q&A)", "Audience questions, most liked first");
    try {
      const interactions = await this.api!.interactions(this.config.eventId!);
      if (!interactions.length) list.appendChild(el("p", "muted", "No interactions yet. Add a poll, word cloud or open ended question in Open Presenter."));
      for (const it of interactions) {
        const item = el("button", "list-item");
        item.type = "button";
        item.appendChild(el("span", "list-title", it.title ?? it.id));
        item.appendChild(el("span", "list-sub", `${label(it.type)} · slide ${it.position + 1}`));
        item.addEventListener("click", () => pick(it.id));
        list.appendChild(item);
      }
    } catch (e) {
      list.appendChild(el("p", "error", errorMessage(e)));
    }
  }

  private async showLive() {
    this.realtime?.disconnect();
    clear(this.root);
    const live = el("div", "screen live");
    this.root.appendChild(live);
    const status = el("div", "status", "");
    const gear = el("button", "gear", "⚙");
    gear.type = "button";
    gear.title = "Change interaction";
    gear.addEventListener("click", () => this.showInteractions());
    live.appendChild(status);
    live.appendChild(gear);
    const content = el("div", "content");
    live.appendChild(content);

    try {
      this.event = await this.api!.event(this.config.eventId!);
    } catch (e) {
      content.appendChild(el("p", "error", errorMessage(e)));
      content.appendChild(linkButton("Reconnect", () => this.start()));
      return;
    }

    const id = this.config.interactionId!;
    const setStatus = (state: ConnectionState) => {
      this.connection = state;
      status.className = `status status-${state}`;
      status.textContent = state === "open" ? "live" : state === "connecting" ? "connecting…" : "offline";
    };

    if (id === JOIN_SCREEN) {
      clear(content);
      await renderJoinPanel(content, this.event, true);
      this.realtime = new Realtime(this.config.serverUrl, this.socketPath, this.socketToken!, {
        onState: setStatus,
      });
      this.realtime.connect(`event:${this.event.id}`);
      return;
    }

    if (id === QA) {
      const draw = () => {
        clear(content);
        const header = el("div", "header");
        header.appendChild(el("h1", "title", "Questions"));
        content.appendChild(header);
        const body = el("div", "body");
        renderPosts(body, this.posts);
        content.appendChild(body);
      };
      const load = async () => {
        this.posts = await this.api!.posts(this.event!.id, "questions");
        draw();
      };
      await load().catch((e) => content.appendChild(el("p", "error", errorMessage(e))));
      this.realtime = new Realtime(this.config.serverUrl, this.socketPath, this.socketToken!, {
        onState: setStatus,
        onPost: () => load().catch(() => undefined),
      });
      this.realtime.connect(`event:${this.event.id}`);
      return;
    }

    const draw = () => {
      clear(content);
      if (!this.interaction) return;
      renderInteraction(content, this.interaction);
      if (this.event) renderJoinPanel(content, this.event);
    };

    try {
      this.interaction = await this.api!.interaction(id);
      draw();
    } catch (e) {
      content.appendChild(el("p", "error", errorMessage(e)));
      content.appendChild(linkButton("Choose another interaction", () => this.showInteractions()));
      return;
    }

    this.realtime = new Realtime(this.config.serverUrl, this.socketPath, this.socketToken!, {
      onState: (s) => {
        setStatus(s);
        if (s === "open") this.realtime?.refresh();
      },
      onInteraction: (it) => {
        this.interaction = it;
        draw();
      },
      onStarted: (it) => {
        this.interaction = it;
        draw();
      },
      onStopped: () => {
        if (this.interaction) this.interaction = { ...this.interaction, enabled: false };
        draw();
      },
      onDeleted: () => {
        clear(content);
        content.appendChild(el("p", "error", "This interaction was deleted."));
        content.appendChild(linkButton("Choose another interaction", () => this.showInteractions()));
      },
    });
    this.realtime.connect(`interaction:${id}`);
  }
}

// ---------- helpers ----------

function input(labelText: string, value: string, type: string) {
  const wrap = el("label", "field");
  wrap.appendChild(el("span", "field-label", labelText));
  const field = el("input");
  field.type = type;
  field.value = value;
  field.autocomplete = "off";
  field.required = true;
  wrap.appendChild(field);
  return { wrap, field };
}

function button(text: string, kind = "") {
  const b = el("button", `btn ${kind}`.trim(), text);
  b.type = "submit";
  return b;
}

function linkButton(text: string, onClick: () => void) {
  const b = el("button", "btn link", text);
  b.type = "button";
  b.addEventListener("click", onClick);
  return b;
}

function label(type: string): string {
  return (
    { poll: "Poll", word_cloud: "Word cloud", open_ended: "Open ended", quiz: "Quiz", form: "Form", embed: "Web content" }[
      type
    ] ?? type
  );
}

function errorMessage(e: unknown): string {
  if (e instanceof ApiError) {
    if (e.status === 401) return "The token was rejected. Generate a new one in Settings → PowerPoint add-in.";
    if (e.status === 0) return e.message + ". Check the server URL.";
    return e.message;
  }
  return e instanceof Error ? e.message : String(e);
}

export function startApplication() {
  new App().start();
}

// Office.onReady resolves once the host has initialised Office.js. Outside
// PowerPoint (plain browser for development) it still resolves, with host null.
declare const Office: typeof globalThis.Office | undefined;
if (typeof Office !== "undefined" && Office?.onReady) {
  Office.onReady(() => startApplication());
} else {
  window.addEventListener("DOMContentLoaded", () => startApplication());
}
