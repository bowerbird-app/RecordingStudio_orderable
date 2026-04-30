# Dummy App

This Rails app exists to validate RecordingStudioOrderable in a real host application.

## What It Covers

- Devise authentication with a seeded admin user
- `Current.actor` wiring for Recording Studio events
- Root workspace and root recording setup
- Folder + Page ordering demo with a FlatPack-first table
- FlatPack layout integration and Tailwind source scanning
- Mounted `RecordingStudio::Engine` route behavior inside a host app

## Quick Start

```bash
bundle install
bin/rails db:setup
bin/dev
```

Then open the app and sign in with:

- Email: `admin@admin.com`
- Password: `Password`

## Useful Routes

- `/` - dummy app home page and template guidance
- `/` - Folder + Page ordering demo
- `/recording_studio` - mounted Recording Studio engine
- `/users/sign_in` - Devise sign-in page
- `/up` - Rails health check

## Why This App Exists

Use this app to verify the generated addon experience before shipping. The seeded demo includes one eligible page that is intentionally omitted from `ordered_recording_ids` so the UI shows the addon’s resilient read behavior, while the underlying model also supports owner-scoped order snapshots in addition to the shared/default order used by the demo.
