// Thin client for the Open Presenter Office API (see docs/office-addin.md).

export interface ApiEvent {
  id: string;
  name: string;
  code: string;
  join_code: string;
  join_url: string;
  slides: number;
  position: number | null;
}

export interface PollOption {
  id: number;
  content: string;
  vote_count: number;
  percentage: number;
}

export interface Word {
  text: string;
  count: number;
  size?: number;
}

export interface OpenEndedResponse {
  id: number;
  text: string;
  vote_count: number;
  inserted_at: string;
}

export interface QuizOption {
  id: number;
  content: string;
  is_correct: boolean;
  response_count: number;
  percentage: number;
}

export interface QuizQuestion {
  id: number;
  content: string;
  type: string;
  options: QuizOption[];
}

export type InteractionType = "poll" | "word_cloud" | "open_ended" | "quiz" | "form" | "embed";

export interface Interaction {
  id: string;
  numeric_id: number;
  type: InteractionType;
  title: string | null;
  position: number;
  enabled: boolean;
  event_id?: string;
  join_code?: string;
  join_url?: string;
  results: {
    multiple?: boolean;
    show_results?: boolean;
    total_votes?: number;
    options?: PollOption[];
    total?: number;
    words?: Word[];
    responses?: OpenEndedResponse[];
    voting_enabled?: boolean;
    auto_scroll?: boolean;
    questions?: QuizQuestion[];
    submit_count?: number;
    provider?: string;
    content?: string;
  };
}

export interface AuthInfo {
  user: { id: number; email: string };
  token_name: string;
  scopes: string[];
  socket_token: string;
  socket_token_expires_in: number;
  socket_path: string;
}

export interface Post {
  id: string;
  body: string;
  name: string | null;
  pinned: boolean;
  like_count: number;
  love_count: number;
  lol_count: number;
  inserted_at: string;
}

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
  }
}

export class Api {
  constructor(
    private serverUrl: string,
    private token: string,
  ) {}

  get base(): string {
    return this.serverUrl.replace(/\/+$/, "");
  }

  private async request<T>(method: string, path: string): Promise<T> {
    let response: Response;
    try {
      response = await fetch(this.base + "/api/office" + path, {
        method,
        headers: { Authorization: `Bearer ${this.token}`, Accept: "application/json" },
      });
    } catch (e) {
      throw new ApiError(0, `Cannot reach ${this.base}`);
    }
    if (!response.ok) {
      let message = `${response.status} ${response.statusText}`;
      try {
        const body = await response.json();
        if (body?.message) message = body.message;
        else if (body?.error) message = body.error;
      } catch (_e) {
        // not JSON
      }
      throw new ApiError(response.status, message);
    }
    const body = await response.json();
    return body.data as T;
  }

  auth(): Promise<AuthInfo> {
    return this.request("POST", "/auth/token");
  }

  events(): Promise<ApiEvent[]> {
    return this.request("GET", "/events");
  }

  event(id: string): Promise<ApiEvent> {
    return this.request("GET", `/events/${encodeURIComponent(id)}`);
  }

  interactions(eventId: string): Promise<Interaction[]> {
    return this.request("GET", `/events/${encodeURIComponent(eventId)}/interactions`);
  }

  interaction(id: string): Promise<Interaction> {
    return this.request("GET", `/interactions/${encodeURIComponent(id)}`);
  }

  posts(eventId: string, filter: "all" | "pinned" | "questions" = "questions"): Promise<Post[]> {
    return this.request("GET", `/events/${encodeURIComponent(eventId)}/posts?filter=${filter}`);
  }

  activate(id: string): Promise<Interaction> {
    return this.request("POST", `/interactions/${encodeURIComponent(id)}/activate`);
  }

  deactivate(id: string): Promise<Interaction> {
    return this.request("POST", `/interactions/${encodeURIComponent(id)}/deactivate`);
  }
}
