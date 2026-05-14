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
  - `recording_orders(owner: nil)`
  - `recording_order_for(group_key, owner: nil)`
  - `find_or_create_recording_order!(group_key, owner: nil)`
  - `named_recording_orders(group_key, owner: nil)`
  - `named_recording_order_recording_for(order_recording_id, group_key, owner: nil)`
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

- **Default:** After a successful drag-save, a FlatPack alert is rendered in the UI.
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

The mountable engine exposes a simple named-list creation page at `new_recording_order_list_path`. Host apps can pass `parent_recording_id`, `group_key`, an optional `source_order_recording_id`, and an optional local-only `redirect_to`. Owner resolution is intentionally host-controlled:

```ruby
RecordingStudioOrderable.configure do |config|
  config.authenticate_controller = ->(controller) { controller.authenticate_user! }
  config.current_owner_resolver = ->(controller) { controller.current_user }
end
```

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
4. Register host recordable types with Recording Studio as usual.
5. Opt parent recordables into one or more order groups.

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
