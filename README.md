# RecordingStudioOrderable

RecordingStudioOrderable adds opt-in ordered child collections to Recording Studio parent recordables.

It keeps `RecordingStudio::Recording` lightweight by storing order state on an explicit `RecordingStudio::RecordingStudioOrder` child recordable. Each order snapshot stores `ordered_recording_ids` in a UUID array on the recordable itself and is identified by a `(parent_recording, group_key, owner_type, owner_id)` scope.

## What it provides

- Parent opt-in DSL:
  ```ruby
  class Folder < ApplicationRecord
    include RecordingStudioOrderable::OrderableRecordable

    recording_studio_order_group :pages, allows: ["Page"]
  end
  ```
- Recording-level APIs:
  - `recording_orders(owner: nil, group: nil, orderable_name: nil)`
  - `recording_order_for(group_key, owner: nil)`
  - `find_or_create_recording_order!(group_key, owner: nil)`
  - `children_for_order_group`
  - `ordered_children_for(group_key, owner: nil)`
- `RecordingStudio::RecordingStudioOrder` mutation helpers:
  - `ordered_child_recordings`
  - `normalized_ordered_recording_ids`
  - `include_child!`
  - `remove_child!`
  - `move_before!`
  - `move_after!`
  - `move_to_start!`
  - `move_to_end!`
  - `reorder!`
  - `cleanup_missing_children!`

## Read behavior

Reads are resilient by design:

- stale ids in `ordered_recording_ids` are ignored
- unordered eligible children are appended automatically
- fallback order is `created_at ASC, id ASC`

That means you can persist partial order state without broad lifecycle observers on child changes.

## Write behavior

Order mutations prefer Recording Studio’s revise-style behavior. Updating an order revises the active `RecordingStudio::RecordingStudioOrder` child recording rather than storing order metadata on `RecordingStudio::Recording`. Event logging for these mutations stays opt-in and is disabled by default.


## Drag-save notification and event contract

The drag-to-reorder UI supports two notification modes:

- **Default:** After a successful drag-save, the client revisits the page so the standard Rails flash notice can render.
- **Custom event:** If you set <code>send_custom_event: true</code> on the drag-save form, the engine will dispatch a <code>recordingstudio:order:updated</code> event on <code>document</code> with a payload like:

  ```js
  document.addEventListener("recordingstudio:order:updated", (event) => {
    // event.detail = { message, status, selected_order_recording_id, moving_recording_id, target_position }
    console.log(event.detail.message)
  })
  ```

This allows host apps to integrate their own notification system (toast, snackbar, etc.) or handle order updates however they wish.

Interactive reorder UIs do not have to submit the full visible UUID list. The dummy app now sends a minimal move payload (`moving_recording_id` plus the target position), and `RecordingStudio::RecordingStudioOrder` rebuilds the next explicit snapshot from the current resolved order. That means newly eligible children that were previously only auto-appended on read are folded into the next persisted revision whenever a user performs another explicit move.

`group_key` identifies the named order definition (`"pages"`, `"dashboard"`, etc.). `owner_type` and `owner_id` allow the same parent and group to have either a shared/default order or an owner-scoped order such as a user-specific arrangement.

Named lists build on top of that owner scope. The unnamed/default order remains singleton per `(parent_recording, group_key, owner_type, owner_id)`, while additional named lists can coexist for the same owner and group. Duplicate names are allowed, so host apps should select named lists by their `RecordingStudio::Recording` id rather than by `name`.

`recording_orders` can now also narrow results with optional filters:

- `group:` accepts either a group key (`:pages`) or an allowed recordable type string (`"Page"`) when that type maps to exactly one configured group.
- `orderable_name:` matches a specific named list by exact order name.
- Named-only list queries can be composed with `recording_orders(..., named_only: true)`.

The mountable engine exposes a simple named-list creation page at `new_recording_order_list_path`. Host apps can pass `parent_recording_id`, `group_key`, an optional `source_order_recording_id`, and an optional local-only `redirect_to`. Parent-recording authorization is host-controlled. Authentication now defaults to Recording Studio actor resolution (`RecordingStudio.configuration.actor`), and owner resolution can also default to that same actor resolver unless overridden.

```ruby
RecordingStudioOrderable.configure do |config|
  # Optional additional host auth check after Recording Studio actor auth passes.
  config.authenticate_controller = ->(controller) { controller.authenticate_user! }
  config.current_owner_resolver = ->(_controller) { RecordingStudio.configuration.actor&.call }
  config.authorize_parent_recording = lambda do |controller, parent_recording|
    controller.current_user.present? && parent_recording.present?
  end
end
```

`authorize_parent_recording` should enforce your real host-app policy for the resolved `RecordingStudio::Recording`, not just the presence of a logged-in user. Invalid engine configuration now raises a boot-time error instead of being ignored silently.

Default unnamed orders are also enforced as singleton records at the database layer per `(parent_recording, group_key, owner_type, owner_id)` scope. Named lists remain unrestricted by `name` and should still be addressed by their `RecordingStudio::Recording` id.

Addon-specific semantic event logging is optional and quiet by default:

```ruby
RecordingStudioOrderable.configure do |config|
  config.log_order_events = false
end
```

## Installation

1. Add the gem and run `bundle install`.
2. Install the initializer and mount route:
   ```bash
   rails generate recording_studio_orderable:install
   ```
3. Copy migrations:
   ```bash
   rails generate recording_studio_orderable:migrations
   bin/rails db:migrate
   ```
  If older unnamed orders already exist for the same parent/group/owner scope, the migration preserves the newest one as the default and renames the older duplicates so the unique index can be added safely.
4. Configure `authorize_parent_recording` in the generated initializer before exposing the mounted UI. `current_owner_resolver` is optional and only needed if you want behavior different from the default `RecordingStudio.configuration.actor` fallback. `authenticate_controller` is optional and runs as an additional host-auth check after the Recording Studio actor-based authentication passes.
5. Register host recordable types with Recording Studio as usual.
6. Opt parent recordables into one or more order groups.

## Example

```ruby
folder_recording = root_recording.record(Folder, parent_recording: root_recording) do |folder|
  folder.name = "Order Demo"
end

page_one = root_recording.record(Page, parent_recording: folder_recording) { |page| page.title = "Mix notes" }
page_two = root_recording.record(Page, parent_recording: folder_recording) { |page| page.title = "Checklist" }
page_three = root_recording.record(Page, parent_recording: folder_recording) { |page| page.title = "Auto appended" }

page_order = folder_recording.find_or_create_recording_order!(:pages)
page_order.reorder!(ordered_recording_ids: [page_two.id, page_one.id])

folder_recording.ordered_children_for(:pages).map { |recording| recording.recordable.title }
# => ["Checklist", "Mix notes", "Auto appended"]
```

## Dummy app

`test/dummy` includes a Folder + Page demo with:

- Devise login
- FlatPack sidebar shell
- FlatPack table with drag/drop reorder
- current-user-owned named page-order lists created through the mounted engine page
- dummy-owned Setup, Config, Methods, and Views documentation pages
- an eligible page intentionally omitted from `ordered_recording_ids`

Quick start:

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Login:

| Field    | Value           |
|----------|-----------------|
| Email    | admin@admin.com |
| Password | Password        |
