# Dummy App

This Rails app exists to validate Recording Studio Orderable inside a realistic host application.

## What It Covers

- Devise authentication with a seeded admin user
- `Current.actor` wiring for Recording Studio 4.1 and addon events
- Workspace, project, folder, and page examples
- Explicit orderable opt-in on `Folder` only, limited to `Page` children
- Sibling reorder on the home page through Flatpack buttons
- Events page for `log_event!` reorder history
- Recording Studio core default layout, not a sidebar shell

## Quick Start

```bash
bundle install
bin/rails db:setup
bin/dev
```

Then sign in with:

- Email: `admin@admin.com`
- Password: `Password`

## Useful Routes

- `/` - dummy app demo home page
- `/events` - reorder event history
- `/recording_studio` - mounted Recording Studio engine
- `/recording_studio_orderable` - addon overview page
