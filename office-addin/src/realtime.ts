// Realtime connection to the Office channel (Phoenix Channels over WebSocket).
//
// The Phoenix client reconnects with back-off on its own. On top of that we
// force a reconnect when the page becomes visible or the network comes back,
// because a socket can look OPEN while it is a zombie after the machine slept.

import { Socket, Channel } from "phoenix";
import type { Interaction, Post } from "./api";

export type ConnectionState = "connecting" | "open" | "closed";

export interface RealtimeHandlers {
  onInteraction?: (interaction: Interaction) => void;
  onStarted?: (interaction: Interaction) => void;
  onStopped?: () => void;
  onDeleted?: () => void;
  onCurrentInteraction?: (interaction: Interaction | null) => void;
  onPost?: (event: string, post: Post) => void;
  onState?: (state: ConnectionState) => void;
}

export class Realtime {
  private socket: Socket | null = null;
  private channel: Channel | null = null;
  private onVisible = () => this.wake();

  constructor(
    private serverUrl: string,
    private socketPath: string,
    private socketToken: string,
    private handlers: RealtimeHandlers,
  ) {}

  private wsUrl(): string {
    const base = this.serverUrl.replace(/\/+$/, "").replace(/^http/, "ws");
    return base + this.socketPath;
  }

  connect(topic: string): void {
    this.disconnect();
    this.handlers.onState?.("connecting");

    const socket = new Socket(this.wsUrl(), {
      params: { token: this.socketToken },
      reconnectAfterMs: (tries: number) => [1000, 2000, 5000][tries - 1] || 10000,
      heartbeatIntervalMs: 20000,
    });
    socket.onOpen(() => this.handlers.onState?.("open"));
    socket.onClose(() => this.handlers.onState?.("closed"));
    socket.onError(() => this.handlers.onState?.("closed"));
    socket.connect();

    const channel = socket.channel(topic, {});
    channel.on("interaction_updated", (p: { interaction: Interaction }) =>
      this.handlers.onInteraction?.(p.interaction),
    );
    channel.on("interaction_started", (p: { interaction: Interaction }) =>
      this.handlers.onStarted?.(p.interaction),
    );
    channel.on("interaction_stopped", () => this.handlers.onStopped?.());
    channel.on("interaction_deleted", () => this.handlers.onDeleted?.());
    channel.on("current_interaction", (p: { interaction: Interaction | null }) =>
      this.handlers.onCurrentInteraction?.(p.interaction),
    );
    for (const name of [
      "post_created",
      "post_updated",
      "post_deleted",
      "post_pinned",
      "post_unpinned",
      "reaction_added",
      "reaction_removed",
    ]) {
      channel.on(name, (p: { post: Post }) => this.handlers.onPost?.(name, p.post));
    }

    channel
      .join()
      .receive("ok", (reply: { interaction?: Interaction }) => {
        if (reply.interaction) this.handlers.onInteraction?.(reply.interaction);
      })
      .receive("error", () => this.handlers.onState?.("closed"));

    this.socket = socket;
    this.channel = channel;

    document.addEventListener("visibilitychange", this.onVisible);
    window.addEventListener("focus", this.onVisible);
    window.addEventListener("online", this.onVisible);
  }

  refresh(): void {
    this.channel?.push("refresh", {});
  }

  private wake(): void {
    if (document.visibilityState === "hidden") return;
    const socket = this.socket;
    if (!socket) return;
    // A socket reported as open may be dead after sleep: force a reconnect.
    if (socket.isConnected()) {
      socket.disconnect(() => socket.connect());
    } else {
      socket.connect();
    }
  }

  disconnect(): void {
    document.removeEventListener("visibilitychange", this.onVisible);
    window.removeEventListener("focus", this.onVisible);
    window.removeEventListener("online", this.onVisible);
    this.channel?.leave();
    this.socket?.disconnect();
    this.channel = null;
    this.socket = null;
  }
}
