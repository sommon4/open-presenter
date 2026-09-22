# Open Ended

A native interaction for free-text responses shown as cards, in the style of
Mentimeter's "Open Ended" slide.

## Settings

| Setting | Default | Effect |
|---|---|---|
| Maximum characters | 200 (1..1000) | length of one response (graphemes) |
| Multiple responses per person | on | off = one response per attendee |
| Auto-scroll to new responses | off | presenter and add-in scroll to the newest card |
| Vote on responses | off | attendees can 👍 a response (one vote per attendee per response) |
| Show responses to attendees | on | attendees see everyone's responses on their phone |
| Moderate responses | off | responses wait for approval in the manager |

## Data model

```
open_ended            id, title, position, enabled, max_characters, multiple_responses,
                      voting_enabled, auto_scroll, show_results, moderation_enabled
open_ended_responses  id, open_ended_id, text, status, vote_count, attendee_identifier | user_id
open_ended_votes      id, open_ended_response_id, attendee_identifier | user_id (unique)
```

Responses go through the same cleaning as word cloud answers (tags, control
characters, whitespace, NFC) but keep their case. A hard cap of 500 responses
per question protects the presenter screen.

## API

- `Claper.OpenEnded.submit_response/4` → `{:ok, response, open_ended}` or
  `{:error, :disabled | :rate_limited | :empty | :too_long | :limit_reached | :full}`
- `Claper.OpenEnded.toggle_vote/4` → `{:ok, :voted | :unvoted, open_ended}`
- `moderate_response/3`, `delete_response/2`, `delete_all_responses/2`, `export_rows/1`

Broadcast: `{:open_ended_updated, %OpenEnded{responses: [...], total: n}}`.

## UI

- Manager options: show on presentation (`poll_visible`), vote on responses,
  auto-scroll, attendee visibility, response list with remove, reset,
  moderation queue.
- Attendee: response box, own responses, everyone's responses with vote
  buttons (`aria-pressed` reflects the attendee's vote).
- Presenter: card grid (`OpenEndedCardsComponent`), `OpenEndedScroll` hook
  pops new cards and scrolls when auto-scroll is on.
- Export: `POST /export/open_ended/:id` → `Response, Votes, Status, Sent at (UTC)`.
