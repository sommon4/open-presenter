# Presenter panel layout and poll reset

## Panel layout (poll, word cloud, open ended on the presenter page)

By default an active interaction covers the whole presenter screen
("Full screen"). When the slide must stay visible, the Event Manager offers
**Position on presentation** in *Current Interaction Settings*:

| Layout | Presenter screen |
|---|---|
| Full screen | as before: the panel covers the slide |
| Side panel | slide on the left, panel on the right; **Size** = panel width (15–75 %) |
| Bottom bar | slide on top, panel under it; **Size** = panel height (15–75 % of the screen); poll options in two columns |
| Corner box | small box on top of the slide; **Size** = box width; choose the corner |

The slide is never covered in *Side panel* and *Bottom bar*: `#slider-wrapper`
gets a padding of the panel size and tiny-slider is refreshed
(`Presenter.refreshSlider`), so the slide shrinks to the remaining area.
When the panel is hidden (toggle *Show results on presentation* off) the
slide takes the full screen again.

Storage: `presentation_states.poll_layout` (`overlay | side | corner | bottom`),
`poll_size` (integer %, 15–75) and `poll_corner`
(`top-left | top-right | bottom-left | bottom-right`). The values are
validated in `Claper.Presentations.PresentationState.changeset/2` and
broadcast with the usual `:state_updated` message, so the presenter page and
the Office API (`state` in the event serializer) follow at once.

Code: `ClaperWeb.EventLive.PresenterPanelComponent` (`panel/1`,
`presenter_attrs/1`, `compact?/2`), manager events `poll-layout`,
`poll-size`, `poll-corner` in `ClaperWeb.EventLive.Manage`, controls in
`ManageInteractionOptionsComponent.layout_settings/1`.

## Reset votes

*Current Interaction Settings* of a poll shows the vote count and a
**Reset votes** button (with confirmation). `Claper.Polls.reset_votes/2`
deletes every `poll_votes` row of the poll and sets every option's
`vote_count` to 0 in one transaction, then broadcasts `:poll_updated`: the
presenter shows 0 %, and every attendee page reloads its vote and shows the
poll form again, so everyone can vote again.

The manager checks ownership with `Polls.get_poll_for_event/2` before the
reset (event `poll-reset`).
