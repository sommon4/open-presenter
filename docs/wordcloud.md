# Word Cloud

A native interaction: attendees send short text answers, the presenter screen
shows them sized by frequency and updated live.

## Data model

```
word_clouds
  id, title, position, enabled
  max_answers (1..10, default 3)        answers per attendee
  max_characters (1..100, default 40)   graphemes, not bytes
  show_results (default true)           live cloud on attendee phones
  merge_case (default true)             "AI" and "ai" count as one
  moderation_enabled (default false)    answers wait for approval
  profanity_filter_enabled (default false)
  presentation_file_id

word_cloud_responses
  id, word_cloud_id, attendee_identifier | user_id
  original_text     display form (trimmed, whitespace collapsed, NFC)
  normalized_text   aggregation key (display form, case folded when merge_case)
  status            approved | pending | rejected
```

## Normalization (`Claper.WordClouds.Normalizer`)

```
input
 ↓ drop invalid UTF-8, strip <tags>, control and zero-width characters
 ↓ trim, collapse whitespace
 ↓ Unicode NFC                          → display form
 ↓ case fold (merge_case)               → key
 ↓ length check (graphemes ≤ max_characters)
```

An answer is a text response, never split on whitespace: "rare disease",
"遺伝学" and "พันธุกรรม" are each one entry.

## Aggregation

`Claper.WordClouds.aggregate/1` groups approved responses by key and returns
`[%{text: "Genetics", count: 17}, ...]` (display text = earliest form,
sorted by count desc then key, max 150 words). `with_sizes/3` maps counts to
24–96 px with a square-root scale so one dominant answer does not crush the
rest. The browser and the add-in compute their own layout from `{text, count}`
with the same spiral algorithm (`assets/js/word_cloud.js`,
`office-addin/src/word_cloud_layout.ts`).

## Submission rules

`submit_response(identity, event_uuid, word_cloud, text)` returns
`{:ok, response, word_cloud}` or `{:error, reason}`:

| reason | meaning |
|---|---|
| `:disabled` | word cloud not active |
| `:rate_limited` | more than 10 submissions in 10 s from this attendee |
| `:empty`, `:too_long` | normalizer rejected the text |
| `:profanity` | blocked word (filter on) |
| `:duplicate` | attendee already sent this key |
| `:limit_reached` | attendee reached `max_answers` |

The profanity filter is an exact match after lower-casing, leetspeak folding
(`$h1t` → `shit`) and dropping non-letters, so "class" or "Scunthorpe" pass.
Extend the list with `WORD_CLOUD_PROFANITY_WORDS=word1,word2`.

## Realtime

Every change broadcasts `{:word_cloud_updated, %WordCloud{words: [...]}}` on
`"event:<uuid>"`. The presenter overlay uses the `poll_visible` presentation
state (same toggle as polls: "Show word cloud on presentation", key `Z`).

## Manager

- Editor: question, limits, options.
- Options panel: show on presentation, show live cloud on attendee devices,
  word list with remove buttons, reset, moderation queue (approve / reject).
- Export: `POST /export/word_clouds/:id` → CSV `Answer, Merged as, Count`.

## Tests

`test/claper/word_clouds_test.exs`, `test/claper/word_clouds/*`,
`test/claper_web/live/event_live/word_cloud_live_test.exs`,
`assets/test/word_cloud_layout_test.mjs`.
