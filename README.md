# RecordingStudioOrderable

RecordingStudioOrderable adds opt-in ordered child collections to Recording Studio parent recordables.

It keeps `RecordingStudio::Recording` lightweight by storing order state on an explicit `RecordingStudio::RecordingOrder` child recordable. Each order snapshot stores `ordered_recording_ids` in a UUID array on the recordable itself.

## What it provides

- Parent opt-in DSL:
  ```ruby
  class Folder < ApplicationRecord
    include RecordingStudioOrderable::OrderableRecordable

    recording_studio_order_group :pages, allows: ["Page"]
  end
  ```
- Recording-level APIs:
  - `recording_orders`
  - `recording_order_for`
  - `find_or_create_recording_order!`
  - `children_for_order_group`
  - `ordered_children_for`
- `RecordingStudio::RecordingOrder` mutation helpers:
  - `include_recording!`
  - `remove_recording!`
  - `reorder_recordings!`
  - `move_recording_to!`
  - `move_recording_higher!`
  - `move_recording_lower!`
  - `cleanup!`

## Read behavior

Reads are resilient by design:

- stale ids in `ordered_recording_ids` are ignored
- unordered eligible children are appended automatically
- fallback order is `created_at ASC, id ASC`

That means you can persist partial order state without broad lifecycle observers on child changes.

## Write behavior

Order mutations prefer Recording Studio’s revise-style behavior. Updating an order revises the active `RecordingStudio::RecordingOrder` child recording rather than storing order metadata on `RecordingStudio::Recording`.

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
  folder.name = "Launch Folder"
end

page_one = root_recording.record(Page, parent_recording: folder_recording) { |page| page.title = "Mix notes" }
page_two = root_recording.record(Page, parent_recording: folder_recording) { |page| page.title = "Checklist" }
page_three = root_recording.record(Page, parent_recording: folder_recording) { |page| page.title = "Auto appended" }

page_order = folder_recording.find_or_create_recording_order!(:pages)
page_order.reorder_recordings!([page_two.id, page_one.id])

folder_recording.ordered_children_for(:pages).map { |recording| recording.recordable.title }
# => ["Checklist", "Mix notes", "Auto appended"]
```

## Dummy app

`test/dummy` includes a Folder + Page demo with:

- Devise login
- FlatPack sidebar shell
- FlatPack table with drag/drop reorder
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
