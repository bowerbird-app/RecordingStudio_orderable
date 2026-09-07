# Recording Studio Orderable

Recording Studio Orderable is the opt-in sibling-position addon for `RecordingStudio`.

It lets a parent recordable type sort its children without creating a product-managed order object in the recording tree. Position is a column on the child recording. Reorder history is an event on the parent.

## What the gem provides

- gem name: `recording_studio_orderable`
- Ruby namespace: `RecordingStudioOrderable`
- capability opt-in through `RecordingStudio::Capabilities::Orderable.to`
- namespaced methods on `RecordingStudio::Recording`
  - `recording_studio_orderable_children`
  - `recording_studio_orderable_reorder!`
  - `recording_studio_orderable_move!`
  - `recording_studio_orderable_append!`
- addon-owned migration for `recording_studio_orderable_position` on `recording_studio_recordings`
- optional `log_event!` history when siblings are reordered
- optional RecordingStudioAccessible authorization when that addon is loaded

Installing the gem does not enable order on every recordable.

## Installation

Add the gems to your host app. This addon requires Recording Studio 4.1.0 or newer:

```ruby
gem "recording_studio"
gem "recording_studio_orderable"
```

Then run:

```bash
bundle install
bin/rails generate recording_studio_orderable:install
bin/rails generate recording_studio_orderable:migrations
bin/rails db:migrate
```

## Setup

Mount the engine if you did not use the install generator:

```ruby
mount RecordingStudioOrderable::Engine, at: "/recording_studio_orderable"
```

Configure RecordingStudio normally, then enable Orderable only on the parent types whose children should be sortable:

```ruby
RecordingStudio.configure do |config|
  config.recordable_types = %w[Workspace Project Folder Page]
  config.actor = -> { Current.actor }
end

class Workspace < ApplicationRecord
  recording_studio_recordable label: "Workspace", plural_label: "Workspaces", root: true
end

class Project < ApplicationRecord
  recording_studio_recordable label: "Project", plural_label: "Projects",
                              root: false, allowed_parent_types: ["Workspace"]
end

class Folder < ApplicationRecord
  recording_studio_recordable label: "Folder", plural_label: "Folders", root: false,
                              allowed_parent_types: %w[Workspace Project Folder]

  include RecordingStudio::Capabilities::Orderable.to(allows: ["Page"])
end

class Page < ApplicationRecord
  recording_studio_recordable label: "Page", plural_label: "Pages", root: false,
                              allowed_parent_types: %w[Workspace Project Folder Page]
end

RecordingStudioOrderable.configure do |config|
  config.log_order_events = true
  config.event_action = "reordered"
end
```

## Adding to a recordable

Recordables stay opt-in. Include the capability only on the parent models that should order their children:

```ruby
class Folder < ApplicationRecord
  recording_studio_recordable label: "Folder", plural_label: "Folders", root: false,
                              allowed_parent_types: %w[Workspace Project Folder]

  include RecordingStudio::Capabilities::Orderable.to(allows: ["Page"])
end
```

`allows:` limits which direct child recordable types participate. Omit it to order every direct child.

Media kits use the same shape: enable Orderable on the kit, then reorder image and document siblings inside that kit. Those children stay ordinary recordings. Order is not a snapshot recordable and does not clog the tree.

## Ordering methods

The addon uses addon-owned method names on `RecordingStudio::Recording`:

```ruby
folder_recording.recording_studio_orderable_children
# => Page recordings under the folder, ordered by position then created_at

folder_recording.recording_studio_orderable_reorder!(
  ordered_recording_ids: [page_b.id, page_a.id, page_c.id],
  actor: current_user
)

folder_recording.recording_studio_orderable_move!(
  page_c,
  to_index: 0,
  actor: current_user
)

folder_recording.recording_studio_orderable_append!(
  page_a,
  actor: current_user
)
```

`recording_studio_orderable_append!` moves an eligible child to the end of the sibling list. Hosts do not pass `to_index`. The helper calls the same `move!` path that already clamps a large index to the end.

Reads are resilient:

- requested ids that are not eligible children are ignored
- eligible children missing from the list are appended in `created_at`, `id` order
- `NULL` positions sort last

Writes update `recording_studio_orderable_position` on the child recordings. They do not create, revise, or nest a `RecordingOrder` recordable.

## Events

When `config.log_order_events` is true (the default), a successful reorder calls `log_event!` on the parent:

```ruby
action: "reordered"
metadata: {
  ordered_recording_ids: [...],
  previous_ordered_recording_ids: [...],
  moving_recording_id: "...", # present for move! and append!
  to_index: 0
}
```

Events answer what happened to the parent object. High-churn position lists stay on the recordings table.

## Authorization

If `recording_studio_accessible` is loaded and `config.use_recording_studio_accessible` is true, reorder calls check `config.authorization_role` (default `:edit`). Set an explicit `authorization_resolver` to replace that check. With neither Accessible nor a resolver, reorder is allowed.

## Dummy app

`test/dummy` is a host that proves the gem. It uses Recording Studio's default layout (back, optional close, title, optional buttons, then content) and Flatpack components.

- Sign in as `admin@admin.com` / `Password`
- Folder is the only orderable type (`allows: ["Page"]`)
- Home shows that folder's pages with move controls
- Events lists reorder history from `log_event!`

## Cloud Agent boot

Cloud Agent Builds run `.cursor/install.sh`, then `.cursor/fetch-skills.sh`.
The install hook provisions a cold image. On a warm snapshot it skips apt,
ruby-build, db:prepare, and tailwind when Ruby, bundle, and Postgres are
already usable. Fetch-skills always runs last. `.cursor/start.sh` starts
PostgreSQL on each boot. Rebuild with Draft off to load a new pack. See
[Cursor skills in Cloud Agents](docs/cursor-skills.md).

## Validation

```bash
bundle exec rubocop
bundle exec rake app:test
```
