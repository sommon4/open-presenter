# Architecture

Open Presenter is Claper (Elixir/Phoenix/LiveView) with three additions:

1. Two native interactions: **Word Cloud** and **Open Ended**.
2. An **Office API** (JSON + Phoenix Channels) for the PowerPoint add-in.
3. A **PowerPoint content add-in** (TypeScript, Office.js) served by Phoenix.

There is one backend, one database and one realtime event system.

```
                      ┌──────────────────────────┐
                      │        PowerPoint        │
                      │  ┌────────────────────┐  │
                      │  │ Content add-in     │  │  https://poll.example.com/office/
                      │  │ poll / word cloud  │  │
                      │  │ open ended / quiz  │  │
                      │  │ Q&A / join screen  │  │
                      │  └─────────┬──────────┘  │
                      └────────────┼─────────────┘
                     HTTPS /api/office + WS /office/socket
                                   ▼
                      ┌──────────────────────────┐
   Browser manager ──▶│      Phoenix (Claper)    │◀── Browser presenter
   /e/:code/manage    │  LiveView + Channels     │    /e/:code/presenter
                      │  Phoenix.PubSub          │
                      │   "event:<uuid>"         │
                      └────────────┬─────────────┘
                                   ▼
                              PostgreSQL
                                   ▲
                     Attendee phones  /e/:code (QR)
```

## Contexts

| Context | Files | Purpose |
|---|---|---|
| `Claper.WordClouds` | `lib/claper/word_clouds.ex`, `lib/claper/word_clouds/*` | Word Cloud interaction, normalizer, profanity filter |
| `Claper.OpenEnded` | `lib/claper/open_ended.ex`, `lib/claper/open_ended/*` | Open Ended interaction, responses, votes |
| `Claper.Office` | `lib/claper/office.ex`, `lib/claper/office/*` | access tokens, event/interaction lookup, JSON serializer |
| `Claper.Interactions` | `lib/claper/interactions.ex` | one active interaction per slide (extended) |

## Realtime flow

```
Participant submits         Phoenix validates + inserts
        │                            │
        └──────────────▶ aggregate ──┴──▶ Phoenix.PubSub "event:<uuid>"
                                                │
              ┌─────────────────┬───────────────┼─────────────────┐
              ▼                 ▼               ▼                 ▼
        Manager LiveView  Presenter LiveView  Attendee LiveView  OfficeChannel
        (options panel)   (cloud / cards)    (own answers)       (PowerPoint)
```

Every context broadcasts `{:<type>_updated, struct}` with fresh aggregated
data on the event topic. `ClaperWeb.OfficeChannel` subscribes to the same
topic and translates the messages to `interaction_updated` pushes, so the
add-in and the browser presenter display identical data.

Target latency: well under 500 ms on a regional connection (one insert, one
aggregate query, one broadcast).

## Interactions

All interactions live on a slide (`position`) of a `presentation_file` and
have an `enabled` flag; `Claper.Interactions.enable_interaction/1` makes one
interaction active per slide. Word clouds and open ended questions follow the
Poll/Quiz conventions:

- `list_*_at_position/2`, `get_*_for_event/2` (IDOR-safe), `get_*_current_position/2`
- manager routes `/e/:code/manage/add/<type>` and `/edit/<type>/:id`
- events `<type>-set-active`, `<type>-set-inactive`, `delete-<type>`
- CSV export `POST /export/<type>s/:id`

## Security

- Attendee text is stored after tag stripping and is always HTML-escaped by
  HEEx; the add-in only uses `textContent`.
- Per-attendee limits, duplicate control and a Hammer rate limit
  (10 answers / 10 s) protect public inputs.
- All lookups are scoped to the event (`get_*_for_event`), manager actions
  re-check ownership, Office tokens are hashed (SHA-256) and scoped.
