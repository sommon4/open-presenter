# AGENTS.md

This file provides repository guidance for coding agents working in this project, regardless of vendor or runtime.

## Purpose

Claper is an interactive presentation platform built with Elixir, Phoenix, and LiveView. It supports real-time audience interaction through polls, forms, posts, quizzes, and presentation controls.

Use this document as the canonical agent guide for repository context, workflows, and implementation constraints.

## Working Principles

- Read the relevant existing files before editing them.
- Match existing naming, structure, and conventions instead of introducing new patterns.
- Keep changes targeted and incremental.
- Prefer thin web layers and place business logic in contexts.
- Do not hardcode secrets, credentials, or environment-specific values.
- When changing behavior, add or update tests in the affected area when practical.
- Run the smallest relevant verification steps before finishing.

## Common Commands

Prefer running `mix` commands through `./with_env.sh` so values from `.env` are loaded in the shell environment. Use plain `mix ...` only when the task does not depend on repository environment variables.

When running tests, make sure the loaded `.env` sets `MIX_ENV=test` before invoking `./with_env.sh mix test`. Do not run tests against a shell environment configured for `dev` or `prod`.

### Setup and Dependencies

```bash
./with_env.sh mix deps.get
./with_env.sh mix setup
./with_env.sh mix ecto.setup
./with_env.sh mix ecto.reset
cd assets && npm install && cd ..
```

### Running the Application

```bash
./with_env.sh mix phx.server
./with_env.sh iex -S mix phx.server
```

### Testing and Quality

```bash
# Ensure `.env` contains `MIX_ENV=test` before running test commands
./with_env.sh mix test
./with_env.sh mix test test/path/to/test_file.exs
./with_env.sh mix test test/path/to/test_file.exs:42
./with_env.sh mix format
./with_env.sh mix credo
```

### Localization

```bash
./with_env.sh mix gettext.extract
./with_env.sh mix gettext.merge priv/gettext
```

### Assets and Production Build

```bash
./with_env.sh mix assets.deploy
```

## Architecture Overview

### Core Stack

- Phoenix + LiveView for real-time UI
- PostgreSQL + Ecto for persistence
- Oban for background jobs
- Tailwind CSS + DaisyUI for styling
- Alpine.js for lightweight client-side interactions
- esbuild for frontend bundling

### Main Contexts

- `Accounts` for users, auth, roles, and OIDC
- `Events` for presentation and event management
- `Posts` for audience messages and reactions
- `Polls` for voting flows
- `Forms` for feedback forms
- `Quizzes` for quiz flows and LTI integration
- `Presentations` for slide and state management
- `Embeds` for external content embedding

### Main Web Areas

- `lib/claper_web/live/event_live/show*` for attendee-facing interactions
- `lib/claper_web/live/event_live/presenter*` for presenter controls
- `lib/claper_web/live/event_live/manage*` for event management
- `lib/claper_web/live/admin_live/` for admin interfaces

### Real-Time Patterns

- Use Phoenix PubSub for event broadcasts
- Use Phoenix Presence for online user tracking
- Event-scoped topics commonly follow `"event:#{event.uuid}"`

## Project Conventions

### Elixir and Phoenix

- Context modules live in `lib/claper/`
- Schemas typically live in `lib/claper/<context>/`
- Use `Claper.Repo` and Ecto queries instead of raw SQL
- Keep LiveViews thin and move reusable business logic into contexts
- Common LiveView callbacks include `mount/3`, `handle_params/3`, `handle_event/3`, and `handle_info/2`
- Use `assign/2` and `assign_new/2` for LiveView state management
- Every new user-facing text must be localized with Gettext instead of hardcoded strings
- After adding or changing translatable strings, run `./with_env.sh mix gettext.extract` and `./with_env.sh mix gettext.merge priv/gettext`

### Database

- Migrations live in `priv/repo/migrations/`
- Public identifiers commonly use UUIDs
- Schemas use `Claper.Schema` as the base when appropriate
- Set `on_delete` behavior explicitly for foreign keys in migrations
- Prefer reversible migrations when possible
- Avoid destructive migrations without a backfill or rollout plan

### Frontend

- Follow existing Tailwind and DaisyUI usage
- Prefer LiveView interactions over custom JavaScript when possible
- Use Alpine.js only where lightweight client-side behavior is justified

### Auth and Access Control

- Check ownership or role before any mutation
- Route-level auth belongs in plugs under `lib/claper_web/plugs/`
- LiveView auth should use existing `on_mount` patterns
- Be alert for IDOR risks when loading resources from params

## Testing Guidance

- Context tests usually live in `test/claper/`
- Web and LiveView tests usually live in `test/claper_web/`
- Use `Claper.DataCase` for context tests
- Use `ClaperWeb.ConnCase` for controller and web tests
- Match existing fixtures and helpers from `test/support/`
- Cover happy paths, validation failures, and authorization boundaries
- For PubSub and LiveView features, verify relevant events and UI updates

## Security and Safety Checks

Before finishing sensitive changes, review for:

- SQL injection risks from interpolated queries
- XSS risks from unsafe rendering of user content
- Missing authorization checks on mutations and admin flows
- IDOR risks from unscoped resource lookups
- Secret leakage in code, logs, or assigns
- Unsafe command execution with user input
- PubSub topics that expose cross-event data

## Operations and Deployment

- Runtime configuration should come from environment variables, especially in `config/runtime.exs`
- Keep Docker and CI changes minimal, cache-friendly, and explicit
- Ensure production releases still support migrations through `lib/claper/release.ex`
- Update `.env.sample` when introducing required environment variables
- Ensure assets are built for production changes that require them

## Change Strategy

When implementing work:

1. Understand the request and inspect the affected code paths.
2. Identify the smallest coherent change that fits existing architecture.
3. Implement with minimal surface area.
4. Run relevant checks such as `mix format`, `mix test`, or `mix credo`.
5. Note any remaining risks, skipped checks, or follow-up work.
