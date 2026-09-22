# Open Presenter

Self-hosted audience interaction — polls, **word clouds**, **open ended
questions**, quizzes, Q&A, forms — that runs inside **PowerPoint** and in the
browser. Built on [Claper](https://github.com/ClaperCo/Claper) (Elixir /
Phoenix / LiveView), licensed AGPL-3.0.

```
Slide 3  [Open Presenter word cloud]  "What causes diagnostic delay?"
            ▲                                    │
   attendees scan the QR ─────────── answers ────┘  → the slide updates live
```

## What is new compared to Claper

| Feature | Where |
|---|---|
| Word Cloud interaction (normalization, merging, moderation, profanity filter, export) | `docs/wordcloud.md` |
| Open Ended interaction (multiple responses, voting, auto-scroll, moderation, export) | `docs/open-ended.md` |
| Office API + realtime channel, personal access tokens in Settings | `docs/office-addin.md` |
| PowerPoint content add-in (poll, word cloud, open ended, quiz, Q&A, join QR) | `office-addin/`, `docs/office-addin.md` |
| Production Docker image (add-in included), Compose, GitHub Actions → GHCR, `/health` | `docs/deployment.md` |

Everything Claper already does (presentations, polls, quizzes, Q&A, forms,
embeds, QR join, presenter mode, LTI, OIDC, transcription) still works; see
`docs/CLAPER-README.md`.

## Quick start (development)

```bash
# Elixir 1.18 / OTP 28 / Node 22 / PostgreSQL (see .tool-versions)
cp .env.sample .env            # DATABASE_URL, SECRET_KEY_BASE, MIX_ENV=dev
./with_env.sh mix setup
./with_env.sh mix phx.server   # http://localhost:4000  (admin@claper.co / see seeds)

cd office-addin && npm install && npm run certs && npm run dev   # https://localhost:3000
npm run manifest && # sideload office-addin/manifest.xml in PowerPoint
```

Tests:

```bash
MIX_ENV=test ./with_env.sh mix test      # Elixir (contexts, LiveViews, API, channel)
cd assets && npm test                     # web hooks (word cloud layout)
cd office-addin && npm run build && npm test
```

## Production

```bash
cp .env.example .env && nano .env
docker compose pull && docker compose up -d      # behind an existing Traefik
# or: docker compose -f docker-compose.standalone.yml up -d   # with bundled Caddy/TLS
```

Details, DNS, backups and Hostinger notes: `docs/deployment.md`.

## Presenting from PowerPoint

1. Settings → **PowerPoint add-in** → Generate token.
2. Download `https://<your host>/office/manifest.xml` and sideload it once.
3. PowerPoint → Insert → My Add-ins → Open Presenter → paste the token →
   pick the event → pick the interaction (or *Join screen* / *Questions*).
4. Start the slideshow. Attendees scan the QR on the slide; answers appear
   live on the slide and in the browser presenter.

## Repository layout

```
lib/claper/word_clouds*   lib/claper/open_ended*   lib/claper/office*
lib/claper_web/live/word_cloud_live  open_ended_live  event_live/*component.ex
lib/claper_web/controllers/office/   lib/claper_web/channels/office_*
office-addin/             docs/               THIRD_PARTY_LICENSES/   NOTICE
```

## License

AGPL-3.0 (see `LICENSE.txt`). Word cloud behaviour was modelled on
[Jackpoll](https://github.com/jackpoll-org/jackpoll) (MIT) and the manifest
on [Live-Poll](https://github.com/livepoll/live-poll-powerpoint) (MIT); their
notices are kept in `THIRD_PARTY_LICENSES/` — see `NOTICE`.
