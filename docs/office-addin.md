# PowerPoint add-in and Office API

The add-in is a **Content Add-in** (`xsi:type="ContentApp"`, host
`Presentation`): it is embedded in a slide like a picture and keeps running
during the slideshow. It is a thin client; all logic stays in Phoenix.

```
PowerPoint slide ──▶ https://poll.example.com/office/index.html ──▶ Office API
                                                                 └─▶ /office/socket (WebSocket)
```

## Office API

Authentication: `Authorization: Bearer claper_office_...`. Tokens are created
in **Settings → PowerPoint add-in**; only a SHA-256 hash is stored.

Scopes: `office:events:read`, `office:interactions:read`,
`office:presentation:read` (default) and `office:interactions:write`
(optional, lets the add-in start/stop interactions).

| Method | Path | Returns |
|---|---|---|
| POST | `/api/office/auth/token` | user, scopes, `socket_token` (12 h), `socket_path` |
| GET | `/api/office/events` | events the user owns or facilitates |
| GET | `/api/office/events/:uuid` | one event with `join_url`, `join_code`, `slides`, `position` |
| GET | `/api/office/events/:uuid/interactions` | all interactions, slide order |
| GET | `/api/office/events/:uuid/state` | presentation state + active interaction |
| GET | `/api/office/events/:uuid/posts?filter=all\|pinned\|questions` | Q&A posts |
| GET | `/api/office/interactions/:id` | interaction with `results` |
| GET | `/api/office/interactions/:id/results` | results only |
| POST | `/api/office/interactions/:id/activate` | write scope |
| POST | `/api/office/interactions/:id/deactivate` | write scope |

Interaction ids are public strings: `poll_12`, `word_cloud_3`,
`open_ended_5`, `quiz_7`, `form_2`, `embed_1`.

```json
{
  "id": "word_cloud_3", "type": "word_cloud", "title": "Describe today's session",
  "position": 2, "enabled": true,
  "event_id": "…", "join_code": "A7KD2", "join_url": "https://poll.example.com/e/a7kd2",
  "results": { "total": 17, "words": [{ "text": "genetics", "count": 17, "size": 96 }] }
}
```

`results` per type: poll `{multiple, total_votes, options[{content, vote_count, percentage}]}`;
word_cloud `{total, words[{text, count, size}]}`; open_ended
`{total, voting_enabled, auto_scroll, responses[{id, text, vote_count}]}`;
quiz `{show_results, questions[{content, options[{content, is_correct, response_count, percentage}]}]}`;
form `{submit_count}`; embed `{provider, content}`.

## Realtime channel

Connect to `wss://host/office/socket/websocket?token=<socket_token>`
(Phoenix JS client does this). Topics:

- `interaction:<id>` → `interaction_updated {interaction}`,
  `interaction_started`, `interaction_stopped {id}`, `interaction_deleted {id}`
- `event:<uuid>` → `state_updated {position, ...}`, `current_interaction
  {interaction|null}`, `interaction_updated` for every interaction,
  `post_created` / `post_updated` / `post_deleted` / `post_pinned` /
  `post_unpinned` / `reaction_added` / `reaction_removed` `{post}`

Push `"refresh"` to get a fresh copy after a reconnect.

## Add-in (office-addin/)

```
office-addin/
├── index.html               loads Office.js from Microsoft's CDN, then src/main.ts
├── manifest.template.xml    ContentApp manifest; {{BASE_URL}} / {{ADDIN_ID}} / {{VERSION}}
├── scripts/manifest.mjs     renders manifest.xml for the dev server
├── src/
│   ├── main.ts              flow: setup → event → interaction → live
│   ├── settings.ts          per-instance Office settings + localStorage defaults
│   ├── api.ts               REST client
│   ├── realtime.ts          Phoenix Channel client with wake-up reconnect
│   ├── renderer.ts          poll / word cloud / open ended / quiz / Q&A / QR
│   └── word_cloud_layout.ts spiral layout (same algorithm as the web presenter)
└── test/                    node tests (layout)
```

Slide → interaction mapping: each inserted content add-in is its own embedded
object with its own `Office.context.document.settings` bag, saved in the
.pptx. The add-in stores `{serverUrl, token, eventId, interactionId}` there,
so the mapping survives close/reopen, duplicate slide and move slide.
**Verify this on your PowerPoint builds** with the test cases below; if a
build shares settings between instances, switch to `PowerPoint.run` +
`shape.tags` (requires `PowerPointApi 1.3` in `<Requirements>`).

Special "interactions": `join_screen` (big QR + code) and `qa` (audience
questions, most liked first).

### Development

```bash
cd office-addin
npm install
npm run certs        # installs the Office dev CA and localhost certificate (once)
npm run dev          # https://localhost:3000
npm run manifest     # writes manifest.xml pointing to https://localhost:3000
```

Run Phoenix on http://localhost:4000 (`./with_env.sh mix phx.server`) — the
add-in defaults to that server when served from localhost:3000. Then
sideload `office-addin/manifest.xml`:

- **PowerPoint for Mac**: copy `manifest.xml` to
  `~/Library/Containers/com.microsoft.Powerpoint/Data/Documents/wef/` (create
  `wef` if missing), restart PowerPoint, then *Insert → My Add-ins →
  Developer Add-ins*.
- **Windows**: share the folder that contains `manifest.xml` and add it under
  *File → Options → Trust Center → Trusted Add-in Catalogs*, restart, then
  *Insert → My Add-ins → Shared Folder*.
- **PowerPoint on the web**: *Insert → Add-ins → Upload My Add-in*.

Microsoft's current guides:
https://learn.microsoft.com/office/dev/add-ins/testing/test-debug-office-add-ins

### Production

Phoenix serves the built add-in at `https://<BASE_URL>/office/` and the
manifest at `https://<BASE_URL>/office/manifest.xml` (with the real base URL
and `OFFICE_ADDIN_ID`). Presenters download that file and sideload it, or an
admin deploys it centrally (Microsoft 365 admin center → Integrated apps).
Keep `OFFICE_ADDIN_ID` stable once people have inserted the add-in.

### Manual test plan (Phase 5–7 acceptance)

```
insert add-in on a slide, pick an interaction → results show
close PowerPoint, reopen              → same interaction still mapped
duplicate the slide                   → copy shows the same interaction (change via ⚙)
move the slide                        → mapping unchanged
start slideshow, answer from a phone  → slide updates within ~1 s
disconnect Wi-Fi                      → status pill shows "offline"
reconnect                             → status "live", data refreshed
100 answers in 10 s                   → PowerPoint stays responsive
16:9 and 4:3, windowed / presenter view / full screen
PowerPoint for Mac, Windows, web
```
