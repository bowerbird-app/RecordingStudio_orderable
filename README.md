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
- RecordingStudioAccessible authorization on reorder, move, and append
- Recording Studio API capability actions `reorder` and `move_position` when `recording_studio_api` is loaded
- `RecordingStudio::Orderable::Api.override_openapi` for a per-type title and description on those actions

Installing the gem does not enable order on every recordable.

## Installation

Add the gems to your host app. This addon requires Recording Studio 7.0 or newer and below 8, Accessible 0.44.0 or newer and below 1.0, and Flatpack 0.1.315 or newer:

```ruby
gem "recording_studio"
gem "recording_studio_accessible"
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
  RecordingStudio.enable_capability(:accessible, on: self)
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

## Layout

`config.layout` is the layout for Orderable controllers. `nil` uses `RecordingStudio.configuration.layout`, then `"recording_studio/default_layout"`. A String is a layout name. `false` renders with no layout. A callable is invoked as `call(controller:)` and returns a String, `nil`, or `false`.

```ruby
RecordingStudioOrderable.configure do |config|
  config.layout = "recording_studio/default_layout"
end
```

Mounted pages set `content_for :title` and `content_for :subtitle`. The default layout renders that heading. Back and close use `flat_pack_page_nav`. Page actions use `register_page_nav`.

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
# => positioned pages first, then pages with no position, by created_at and id

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

`recording_studio_orderable_append!` moves an eligible child to the end of the sibling list.

`recording_studio_orderable_move!` and `recording_studio_orderable_append!` require that recording to be an eligible direct child. If it is missing, not a direct child, or excluded by `allows:`, they raise `RecordingStudioOrderable::InvalidChild`.

`recording_studio_orderable_move!` changes the sibling index on the same parent. Do not call Moveable to reorder siblings. Do not use Orderable move! to change parent.

Creating a child does not set `recording_studio_orderable_position`. The column stays `NULL`, including when the parent is orderable and `allows` the child type. `recording_studio_orderable_children` lists children that already have a position first, by that position, then children whose position is `NULL`, by `created_at` and then `id`. The position sort is `ASC NULLS LAST`.

A parent change assigns the end position when the new parent is orderable and allows the child type. Otherwise it clears `recording_studio_orderable_position`. The parent change stays in `saved_changes`. Orderable does not assign the parent. The end position is one past `maximum(:recording_studio_orderable_position)` among eligible siblings. That write happens in the same save.

Sibling lists omit recordings that `Recording.kept` leaves out. Core applies the recording filters addons register. Orderable does not check for a `trashed_at` column and does not load RecordingStudio_trashable. Trashable `1.0.1` registers the trash filter.

Restoring a trashed child on an orderable parent keeps its position when no active sibling already has it. A blank or colliding position moves to the end. The parent lock is taken before that write.

`recording_studio_orderable_reorder!` rejects the whole call and leaves positions unchanged when `ordered_recording_ids` includes a missing, foreign, already-trashed, or duplicate id. It raises `RecordingStudioOrderable::InvalidChild`.

A partial list of unique eligible ids is allowed:

- listed children move to the front in that order
- omitted eligible children are appended in `created_at`, `id` order, including children whose position is `NULL`
- an empty list still appends every eligible child in that same order

Reorder, move, and append are the calls that give every eligible sibling a position. They lock the parent recording, then read the current siblings, write a contiguous `0..n-1` sequence (including children whose position was `NULL`), and log the reorder event before releasing that lock. Concurrent reorder writes for the same parent run one at a time.

Writes set `recording_studio_orderable_position` on the child recordings. They skip callbacks and do not change `updated_at`. They do not create, revise, or nest a `RecordingOrder` recordable.

After reorder, move, or append, positions are a dense `0..n-1` sequence. A newly created child is not in that sequence until one of those calls runs. A move shifts the indexes between the old and new position in one update, scoped to that parent's kept children, then writes the moved row. Reorder writes one update for the rows whose positions change. Append writes the appended row when the other siblings already have their final positions. Moving a child to the end of a dense list shifts that open tail in one update, then writes the appended row. Gaps, duplicates, and nils are normalized by rewriting the rows that differ. The sibling index is `idx_rs_recordings_orderable_sibling_position` on `(parent_recording_id, recording_studio_orderable_position)`.

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

Reorder, move, and append authorize at `SiblingOrder` by calling `RecordingStudioAccessible.authorized?(actor:, recording:, role:)` on the parent recording. `authorization_role` defaults to `:edit`. A blank actor is passed through to Accessible after the host `RecordingStudio` actor resolver, if any. Accessible errors propagate. If Accessible is missing, or Accessible does not allow that role, the call is denied and positions are not written.

A denial raises `RecordingStudioOrderable::NotAuthorized`. The engine controller answers that with HTTP 403. Host controllers that call the ordering methods need the same rescue.

There is no host resolver and no fail-open switch. Grant Accessible roles on the parent recording (or an ancestor) instead.

## JSON API and MCP

When Recording Studio API is loaded, this gem registers `reorder` and `move_position` as member capability actions on capability `:orderable`. HTTP summaries, descriptions, field descriptions, and success text live in `RecordingStudio::Orderable::Api::ACTIONS`. MCP tool descriptions, field descriptions, and success text live in `RecordingStudioOrderable::McpCopy`.

When Recording Studio MCP is loaded, `RecordingStudioOrderable::McpCopy.register!` adds named tools for each recordable type that includes `RecordingStudio::Capabilities::Orderable`. Include `RecordingStudioOrderable::McpCopy.tool_names` on the host MCP server. The host calls `register_server`. A type that does not include Orderable gets no tool.

Each orderable parent gets two tools, because `register_tool` takes one action and `reorder` and `move_position` stay separate actions.

| Tool | Action | What it does |
|---|---|---|
| `order_<noun>` | `reorder` | Sets the sibling order of the direct children this parent allows. |
| `move_<noun>` | `move_position` | Moves one direct child to a new index under the same parent. |

The noun is the type token from `RecordingStudioMcp.tool_name`. That helper uses the type's public name on the public API when the registration exists, and otherwise the class name without its namespace. It singularizes the name. `tool_names` and `registrations` are empty until Recording Studio MCP is loaded.

When `allows:` names one child type, the noun is that child. `List` with `allows: ["ListItem"]` gets `order_list_item` and `move_list_item`. When `allows:` names more than one type, or is omitted, the noun is the parent. `Folder` with no `allows:` gets `order_folder` and `move_folder`. When two parents would share a tool name, each name gains that parent's token as a prefix. `Alpha` and `Beta` that both allow `Widget` get `order_alpha_widget` and `order_betum_widget`, because the helper singularizes `Beta` to `betum`.

`order_list_item` rejects a missing, foreign, already-trashed, or duplicate id and leaves the order unchanged. A partial list moves the listed children to the front and appends omitted eligible children. `move_list_item` keeps the child under the same parent.

Hosts that load MCP need `recording_studio_mcp` `>= 0.45` and `< 0.46`. The gemspec leaves that gem optional. `McpCopy.register!` returns before it registers tools until the gem is loaded.

`override_openapi` still sets the OpenAPI title and description for one recordable type. It does not rename `order_list_item` or `move_list_item`. A title such as "Reorder press center" stays on that type's OpenAPI operation.

```ruby
RecordingStudio::Orderable::Api.override_openapi(
  type: "RecordingStudioPressCenters::PressCenter",
  action: :reorder,
  title: "Reorder press center",
  description: "Sets the order of children in this press center."
)

RecordingStudio::Orderable::Api.override_openapi(
  type: "RecordingStudioPressCenters::PressCenter",
  action: :move_position,
  title: "Move press center position",
  description: "Moves one child to a new index in this press center."
)
```

`openapi_for(action:, type: nil)` returns that copy. `openapi_for(type:, action:)` is the same call. The registered action uses the same lookup, so OpenAPI reads the title and description. `ACTIONS` stays the generic copy. An unknown type, a type with no override, or the other action keeps that generic copy. Named MCP tools keep the titles from the naming rule above.

Hosts list the actions on orderable parent types. Position stays off create and update:

```ruby
RecordingStudioApi.register_recordable_type_api(
  "Folder",
  operations: %i[index show create update],
  capability_actions: %i[reorder move_position],
  auto_capability_actions: false,
  serializer: ->(folder, **) { { name: folder.name, slug: folder.slug } },
  output_keys: %i[name slug],
  writable_attributes: %i[name slug]
)
```

| Verb | Path | Accessible role |
|---|---|---|
| POST | `/recording_studio_api/api/v1/folders/:id/actions/reorder` | `:edit` on the parent |
| POST | `/recording_studio_api/api/v1/folders/:id/actions/move_position` | `:edit` on the parent |

`reorder` takes `ordered_recording_ids`. A partial list of unique eligible child ids is allowed. Listed children move to the front. Omitted eligible children are appended by `created_at` then id. A missing, foreign, already-trashed, or duplicate id raises `RecordingStudioOrderable::InvalidChild` (HTTP 422 on the JSON action) and does not change positions. `move_position` takes `recording_id` and `to_index`. Do not name the action `:move`; that name belongs to Moveable.

Authorization is Accessible only: Recording Studio API `required_role` plus `access_grant.authorize!` with `authorization_role` (default `:edit`) on the parent recording. The handlers call the same recording methods as the HTML screens.

Install Recording Studio API in the host if you want the JSON surface:

```sh
bin/rails generate recording_studio_api:install
bin/rails generate recording_studio_api:migrations
bin/rails db:migrate
```

Turn on `:api_access_point` on roots that should hold API clients, and add `RecordingStudioApi::ApiClient` to `access_actor_types`.

## Internationalization

Static interface copy on the mounted overview page resolves through Rails I18n under
`recording_studio.orderable.*`. English is the only locale shipped by the gem
(`config/locales/en.yml`). Every `t()` call passes an English `default:` so a host
locale without a fallback never shows "translation missing".

Hosts override by defining the same nested keys in their own `config/locales`.
There is no dependency on `recording_studio_internationalization`.

Generator CLI text, developer `ArgumentError`s, `InvalidChild` messages,
configuration load errors, and stored recording names stay English.

### Upgrading to 0.3.0

1. Install Orderable `0.3.0`. No migration.
2. Copy `recording_studio.orderable.home.*` into host locale files when translating.

## Upgrading to 0.4.0

1. Require `recording_studio` 6.1.0 or newer and `flat_pack` 0.1.315 or newer. Keep `view_component` at 4.14 or newer and below 5.
2. Remove `include RecordingStudio::UsesDefaultLayout` and any `layout "recording_studio/default_layout"`. Orderable controllers call `recording_studio_layout { RecordingStudioOrderable.configuration.layout }`. Leave `config.layout` nil to follow the host layout, then the default layout.
3. In a copied overview, set `content_for :title` and `content_for :subtitle`. Replace `recording_studio_page_nav` with `flat_pack_page_nav(round: true, style: :default, ...)`. Register actions with `register_page_nav` or `recording_studio_page_nav_right`.
4. Pass `background:`, `border:`, or `shadow:` to `FlatPack::Card`. The `style:` keyword is gone.
5. No database migration. Position writes stay inside the parent lock. Authorization and the `reordered` event stay the same.

`recording_studio.orderable.home.title` was the old page-nav title. The visible heading is `page_title`.

## Upgrading to 0.5.0

1. Add `recording_studio_accessible` `>= 0.24.2`. This repository tests tag `v0.24.2`.
2. Enable `:accessible` on host roots that should hold grants. Grant `:edit` (or a stronger role) before anyone can reorder.
3. Remove `authorization_resolver`, `use_recording_studio_accessible`, and `accessible_module` from Orderable configuration. Those keys are ignored.
4. Do not rely on reorder allowing every caller when Accessible is off or missing. Direct `SiblingOrder` calls now deny the same way as the recording helpers.
5. No database migration from Orderable. Run Accessible install and migrations in the host if they are not already present.

## Upgrading to 0.6.0

1. Install Orderable `0.6.0`. No Orderable migration.
2. If the host mounts Recording Studio API, list `reorder` and `move_position` on orderable types. Do not add `recording_studio_orderable_position` to writable API fields.
3. Grant Accessible `:edit` (or `authorization_role`) on the parent, the same as the HTML screens. MCP needs no extra Orderable code.

## Upgrading to 0.12.3

1. Install Orderable `0.12.3`. No Orderable migration.
2. New children keep a `NULL` `recording_studio_orderable_position` and list after positioned siblings until reorder, move, or append. Creating many children under one parent no longer deadlocks.
3. Code that reads `recording_studio_orderable_position` directly must handle `NULL`. A parent change or a restore from trash can still write that one child. The `reordered` event shape is unchanged.

## Upgrading to 0.12.2

1. Install Orderable `0.12.2`. No Orderable migration.
2. Hosts that load Recording Studio MCP `0.45` or newer and below `0.46` include `RecordingStudioOrderable::McpCopy.tool_names` on the MCP server. A type that includes Orderable gets `order_<noun>` and `move_<noun>`. The noun comes from `RecordingStudioMcp.tool_name`. One `allows:` entry uses that child, so `List` allowing `ListItem` gets `order_list_item` and `move_list_item`. Several `allows:` entries, or none, use the parent. A type without Orderable gets no tool. `tool_names` is empty until MCP is loaded.
3. `override_openapi` still sets the OpenAPI title and description for one type. It does not rename the named tools.
4. Action names, fields, routes, authorization, position writes, and the `reordered` event stay the same.

## Upgrading to 0.12.1

1. Install Orderable `0.12.1`. No Orderable migration.
2. New children of an orderable parent now take the end sibling position. Existing rows keep their stored positions. A non-orderable parent or a type outside `allows` is unchanged.
3. Dummy and this repository's `.ruby-version` is `3.3.14`. Hosts stay on `>= 3.3.0`.

## Upgrading to 0.12.0

1. Install Orderable `0.12.0`. No Orderable migration. Gemspec floors stay Recording Studio `>= 7.0`, `< 8.0`, Accessible `>= 0.44.0`, `< 1.0`, and Flatpack `>= 0.1.315`. This repository's development pins are Recording Studio `v7.8.0` and Flatpack `v0.2.0`.
2. Hosts MUST run the Recording Studio `7.4`, `7.5`, and `7.7` migrations if they have not (`add_recording_studio_recordings_root_type_creation_index`, `enforce_recording_studio_recording_root_invariant`, and `replace_recording_studio_recordings_root_index`). This repository's dummy app does not copy those migrations.
3. flat_pack 0.2.0 is supported; hosts moving to 0.2 must remove the manual `flat_pack/heroicons` importmap pin and any `flat-pack--icon` controller registration.

## Upgrading to 0.11.1

1. Install Orderable `0.11.1`. No Orderable migration.
2. Hosts MUST run the Recording Studio `7.4`, `7.5`, and `7.7` migrations (`add_recording_studio_recordings_root_type_creation_index`, `enforce_recording_studio_recording_root_invariant`, and `replace_recording_studio_recordings_root_index`). This repository's dummy app does not copy those migrations.
3. Hosts on Recording Studio API `1.4` or newer run `20261117000024_add_owner_to_recording_studio_api_api_clients` and set `owner` on each existing API client.
4. Hosts that mount API `1.12` or newer need `config/recording_studio_api.yml`. `shared: {}` is enough to boot.

## Upgrading to 0.11.0

1. Install Orderable `0.11.0`. No migration.
2. Call `RecordingStudio::Orderable::Api.override_openapi(type:, action:, title:, description:)` for each type whose MCP title should name that type, such as "Reorder press center" on `RecordingStudioPressCenters::PressCenter`.
3. Leave the call out and MCP keeps the generic "Type - Reorder" and "Type - Move Position" titles. Action names, fields, routes, authorization, position writes, and the `reordered` event stay the same.

## Upgrading to 0.10.1

1. Install Orderable `0.10.1`. No Orderable migration.
2. Public MCP copy for `reorder` and `move_position` changed. Action names and fields did not.

## Upgrading to 0.10.0

1. Install Orderable `0.10.0`. No Orderable migration.
2. Require Recording Studio `>= 7.0`, `< 8.0` and Accessible `>= 0.44.0`, `< 1.0`.
3. Create a root with `RecordingStudio.create_root_recording!(recordable, actor:)`. `root_recording_for` only finds an existing root and returns `nil` when there is none.
4. Set `config.authorize_write`. Leave `allow_unauthorized_writes` unset.
5. Sibling order still follows `Recording.kept`. Trashable `0.17.0` registers the trash filter. Hosts do not register it themselves.

## Upgrading to 0.9.0

1. Install Orderable `0.9.0`. No new Orderable migration. Hosts that already ran `20250101000001` keep `idx_rs_recordings_orderable_sibling_position` on `(parent_recording_id, recording_studio_orderable_position)`.
2. Reorder, move, and append still produce the same sibling order and the same `reordered` event. Position writes no longer run recording callbacks and no longer bump `updated_at`.
3. The next reorder, move, or append turns a list with gaps, duplicate positions, or nils into a dense `0..n-1` sequence.

## Upgrading to 0.8.0

1. Install Orderable `0.8.0` and Recording Studio `6.14.0` or newer. No Orderable migration.
2. Copy core migration `20261114090000_add_root_recording_id_to_recording_studio_events` when the host events table has no `root_recording_id`.
3. Sibling order follows `Recording.kept`. Install Trashable `0.16.0` when that tag exists so trashed children stay out of order. A host still on Trashable `0.14.0` registers the trash filter itself until then.

## Upgrading to 0.7.0

1. Install Orderable `0.7.0`. No Orderable migration.
2. Send only unique eligible child ids in `ordered_recording_ids`. A missing, foreign, already-trashed, or duplicate id now raises `RecordingStudioOrderable::InvalidChild` and leaves positions unchanged.
3. Rescue that error as HTTP 422 if the host calls `recording_studio_orderable_reorder!` itself. The JSON `reorder` action already maps it that way.
4. Partial lists stay valid. Listed children move to the front. Omitted eligible children are appended by `created_at` then id.

## Dummy app

`test/dummy` is a host that proves the gem. The root Gemfile and the dummy Gemfile pin Recording Studio tag `v7.8.0` (`~> 7.8`), Accessible tag `v0.56.0`, Trashable tag `v1.2.3`, Metrics tag `v0.10.0`, Flatpack tag `v0.2.0` (`~> 0.2`), Logs tag `v0.8.2`, Moveable tag `v6.0.3`, Icons tag `v0.5.0`, and Admin tag `v2.19.1`. The root Gemfile pins Recording Studio API tag `v1.19.0`. The dummy Gemfile pins API tag `v1.21.3` and Recording Studio MCP tag `v0.45.2` (`>= 0.45`, `< 0.46`). MCP 0.45.2 also needs OAuth tag `v0.26.0`, Cache tag `v0.8.0`, Site Settings tag `v0.7.0`, and Attachable tag `v0.34.0` in that Gemfile. The gemspec does not depend on `recording_studio_mcp`. Those pins are for this repository. Hosts still need Recording Studio 7.0 or newer and below 8, Accessible 0.44.0 or newer and below 1.0, and Flatpack 0.1.315 or newer. Hosts MUST run the Recording Studio 7.4, 7.5, and 7.7 migrations if they have not. This dummy does not copy them. `view_component` stays at 4.19.0. Trashable `1.2.3` registers the trash filter, so the dummy does not. Dummy Workspace enables `:accessible` and `:api_access_point`. The seeded admin owns that workspace. Home loads the workspace through Accessible, not `Workspace.first`. Seeds create that root with `create_root_recording!`. The dummy `authorize_write` callback allows a write when an actor is present. The dummy `config/recording_studio_api.yml` is `shared: {}` so API 1.21 can boot, and the dummy copies API migration `20261117000024` so new API clients can store `owner`. The dummy lists `RecordingStudioAttachable::Attachment` and `RecordingStudioSiteSettings::SiteSetting` in `config.recordable_types` because those engines declare recordables. Hosts moving to Flatpack 0.2 remove the manual `flat_pack/heroicons` importmap pin and any `flat-pack--icon` controller registration. The dummy already dropped that pin.

Orderable's `config.layout` stays nil, so signed-in pages use `RecordingStudio.configuration.layout` and then the default layout. Sign-in uses the application layout. Flatpack stylesheets load before the Tailwind sheet. The home page lists sibling positions and reorders those pages by dragging rows in a modal. The modal table posts FlatPack's reorder payload to the dummy reorder path. Each item id is the recording id string.

Dummy credentials (`test/dummy/config/credentials.yml.enc`) are encrypted with the shared RecordingStudio_* development master key. Set `RAILS_MASTER_KEY` or put that key in `test/dummy/config/master.key` (gitignored). Keep the encrypted file; do not generate a per-repo dummy key.

- Sign in as `admin@admin.com` / `Password`
- Folder is the only orderable type (`allows: ["Page"]`)
- Home shows that folder's pages with move controls
- Events lists reorder history from `log_event!`. The "when" control opens the full timestamp.
- `/recording_studio_api/api/v1/folders/:id/actions/reorder` and `move_position` are the JSON actions

## Cloud Agent boot

Cloud Agent Builds run `.cursor/install.sh`, then `.cursor/fetch-skills.sh`.
The install hook provisions a cold image. On a warm snapshot it skips apt,
ruby-build, db:prepare, and tailwind when Ruby, bundle, and Postgres are
already usable. If `RAILS_MASTER_KEY` is set, `install.sh` writes gitignored
`test/dummy/config/master.key` so dummy credentials decrypt. Fetch-skills
always runs last. `.cursor/start.sh` starts PostgreSQL on each boot. Rebuild
with Draft off to load a new pack. See
[Cursor skills in Cloud Agents](docs/cursor-skills.md).

## Validation

```bash
bundle exec rubocop
bundle exec rake app:test
```

`rake app:test` runs the gem suite, then `test/dummy/test/orderable_mcp_tools_test.rb`. Each of those writes coverage with the minimum turned off. The rake task then collates `coverage/parts` and enforces the 94% line gate on the merged result. Install the dummy bundle into the same `vendor/bundle` as the root bundle, and migrate the dummy test database, before that command. CI does that install with `BUNDLE_GEMFILE` set to `test/dummy/Gemfile` and `BUNDLE_PATH` set to `vendor/bundle`. The rake task forwards that path, from `BUNDLE_PATH` or the root bundle config, into the dummy process. The gem suite does not load Recording Studio API or Recording Studio MCP. The dummy file does, and calls `RecordingStudioMcp.register_tool`. The rest of the dummy suite is `bundle exec rails test` from `test/dummy`.
