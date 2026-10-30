# Project Guidelines

## Architecture

- This repository is the Recording Studio Orderable addon, a Rails mountable engine.
- Keep the engine namespace `RecordingStudioOrderable`.
- Follow the top-level README for how the addon works. The dummy app is the host that proves it.
- Keep changes small and scoped. Do not rewrite template surfaces unless the request requires it.

## UI Conventions

- FlatPack is the default UI system for this repo.
- When editing ERB views, prefer `render FlatPack::...` components over custom HTML when an equivalent component exists.
- Prefer standardized and testable FlatPack ViewComponents over one-off ERB markup or custom JavaScript.
- Keep custom markup limited to semantic wrappers or content that FlatPack does not cover.

## Testing

- The standard root validation command is `bundle exec rake test` from the repository root.
- If a change affects dummy app boot, assets, or migrations, also validate the dummy app setup the same way CI does.
- Add focused regression tests for engine hooks, generators, Recording Studio integration points, and template UX changes.

## Repo Conventions

- Keep internal dependency assumptions intact unless the request explicitly asks to change private gem infrastructure.
- Update docs when template behavior or setup steps change.
- Prefer existing generator, service, and hook patterns over introducing a parallel abstraction.