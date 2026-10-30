# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.4] - 2026-10-30

### Changed

- Configuration loading wraps `Psych::SyntaxError`, `TypeError`, and `ArgumentError` as `ConfigurationLoadError`. An invalid `layout` is still wrapped, because `layout=` raises `ArgumentError`. Other errors propagate.
- The README states that `recording_studio_orderable_move!` is a sibling index. Do not call Moveable to reorder siblings. Do not use Orderable move! to change parent.

### Upgrade Notes

- Bump to `0.4.4`. No migration and no rename of `recording_studio_orderable_move!`.
- A configuration failure that is not `Psych::SyntaxError`, `TypeError`, or `ArgumentError` is no longer wrapped.

## [0.4.3] - 2026-10-30

### Changed

- Authorization calls `RecordingStudioAccessible.authorized?(actor:, recording:, role:)` when a resolver is unset and Accessible is in use. Accessible errors propagate. Blank actors are passed through.
- With no resolver and Accessible not in use, reorder still allows every caller. The README states that warning.
- A denial raises `RecordingStudioOrderable::NotAuthorized`. The engine controller responds with HTTP 403.
- `capability_options_for` no longer rescues `NoMethodError`.
- `config.accessible_module` optionally replaces the `RecordingStudioAccessible` constant. `RecordingStudioOrderable.reset_configuration!` and `configuration=` replace test code that wrote the configuration instance variable.
- Development dependency `minitest-mock` provides `Object#stub`. It is not a runtime dependency.

### Upgrade Notes

- Bump to `0.4.3`. No migration.
- Rescue `RecordingStudioOrderable::NotAuthorized` instead of `ArgumentError` when a reorder is denied. Host controllers that call `reorder!`, `move!`, or `append!` should respond with HTTP 403.
- Do not rely on Accessible errors becoming `false`, or on a blank actor being denied before Accessible runs.
- Set `authorization_resolver`, or load Accessible with `use_recording_studio_accessible` left true, before a request can reorder. Otherwise every caller is allowed.

## [0.4.2] - 2026-10-30

### Changed

- CI creates and uses the `recording_studio_orderable_test` database.
- CI runs Bundler Audit and Brakeman on the dummy app. RuboCop, gem tests, and dummy tests stay in the test job.
- Dummy development dependency `brakeman` is `8.1.0`, which is what `bin/brakeman` requires.

### Upgrade Notes

- Bump to `0.4.2`. No migration and no host API change.

## [0.4.1] - 2026-10-30

### Changed

- Dummy database defaults are `recording_studio_orderable_development` and `recording_studio_orderable_test`. The devcontainer uses the same development name.
- Dummy Gemfile drops unused scaffold gems: `jbuilder`, `image_processing`, `solid_cache`, `solid_queue`, `solid_cable`, `kamal`, and `thruster`.
- RuboCop no longer excludes template paths `lib/gem_template/**` or `test/services/**`.

### Removed

- Dummy Stimulus `hello_controller`, PWA views, the empty makeup-artist examples directory, and `bin/thrust`.

### Notes

These git tags do not match a product release. They stay as they are. This changelog does not retag them.

- `0.2.0` has no `v` prefix. `VERSION` on that tag is `0.2.0`. There is no `v0.2.0` tag.
- `v0.2.4` through `v0.2.9` are dependency-bump tags. `VERSION` on each is still `0.2.3`.
- `v0.3.1` is the dependency-bump tag after `0.3.0`. `VERSION` on that tag is still `0.3.0`. There is no `0.3.1` product release.

### Upgrade Notes

- Bump to `0.4.1`. No migration and no host API change.
- Hosts that copied the dummy database names should use the new defaults, or keep setting `DB_NAME`.

## [0.4.0] - 2026-10-27

### Breaking

- Requires `recording_studio` >= 6.1.0 and `flat_pack` >= 0.1.315. Development pins Recording Studio tag `v6.1.0` and Flatpack commit `1fcbafe94f8eb118f0a22182f63f5110fcc97a56` (`FlatPack::VERSION` 0.1.319). `view_component` stays >= 4.14 and < 5.
- `RecordingStudioOrderable::Configuration#layout` is the Orderable layout setting. `nil` follows `RecordingStudio.configuration.layout`, then `"recording_studio/default_layout"`. A String is a layout name. `false` renders with no layout. A callable is invoked as `call(controller:)` and returns a String, `nil`, or `false`. Anything else raises `ArgumentError`.
- Orderable controllers call `recording_studio_layout`. `RecordingStudio::UsesDefaultLayout` and `layout "recording_studio/default_layout"` are gone.
- The overview sets `content_for :title` and `content_for :subtitle`. Back and close use `flat_pack_page_nav`. `recording_studio_page_nav` is gone. Cards use `background:`, `border:`, or `shadow:`.

### Upgrade Notes

- Bump to `0.4.0`. No migration.
- Require Recording Studio 6.1.0 or newer and Flatpack 0.1.315 or newer before booting.
- Remove `include RecordingStudio::UsesDefaultLayout` from host controllers. Set `RecordingStudio.configuration.layout` for every gem whose own layout is nil, or set `RecordingStudioOrderable.configuration.layout` when Orderable screens should differ.
- Rewrite copied views that call `recording_studio_page_nav` or `FlatPack::Card::Component.new(style:)`.
- `recording_studio.orderable.home.title` is no longer rendered. The heading is `page_title`.
- Sibling position writes, Accessible and resolver checks, and `reordered` event metadata are unchanged.

## [0.3.0] - 2026-10-13

### Added

- English Rails I18n keys under `recording_studio.orderable.*` for the mounted overview page (`config/locales/en.yml`). Every `t()` call passes an English `default:` so a host locale without a fallback never shows "translation missing".
- Host English override coverage: test-only fixture `test/dummy/test/locales/orderable_host_override.en.yml` loaded via `I18n.backend.load_translations` (no `I18n.load_path` mutation) plus a real-page assert.
- Always-loaded boot-order guard `test/dummy/config/locales/recording_studio_orderable_host.en.yml` for the rarely shown `home.body_after` key (engine overview only; not the dummy root happy path), with a render assert.
- Locale regression: every `lib/**/*.rb` file must not mention `i18n.load_path` / `I18n.load_path`.
- Render-level asserts that the overview page English matches main for titles, subtitle, and body copy.

### Upgrade Notes

- Bump to `0.3.0`. No migration.
- English hosts need no change. Copy `recording_studio.orderable.home.*` into host locale files when translating.
- Hosts override by defining the same nested keys in their own `config/locales`.
- Generator CLI text, `ArgumentError` / `InvalidChild` messages, configuration load errors, icon/style tokens, and stored recording names stay untranslated.

## [0.2.3] - 2026-10-01

### Added
- `RecordingStudioOrderable::InvalidChild` when `move!` or `append!` is given a recording that is not an eligible direct child

### Changed
- `reorder!`, `move!`, and `append!` lock the parent recording while reading siblings, writing positions, and logging the reorder event
- Dummy Tailwind `@source` paths also scan `/usr/local/lib/ruby/gems`, so Flatpack utilities compile when Bundler uses Ruby's default gem home

### Upgrade Notes
- Explicit `move!` and `append!` no longer ignore unknown or ineligible recordings. Bulk `reorder!` still ignores stale and ineligible ids.
- No schema changes.

## [0.2.2] - 2026-09-07

### Added
- `recording_studio_orderable_append!` moves an eligible child to the end of the sibling list. Hosts no longer compute `to_index` for append.

### Upgrade Notes
- No host or schema changes. `recording_studio_orderable_move!` and `recording_studio_orderable_reorder!` are unchanged.
- To append, call `parent.recording_studio_orderable_append!(child, actor: current_user)` instead of `move!` with the last index.

## [0.2.1] - 2026-09-02

Cloud Agent Builds match Recording Studio Billing v0.9.13. Skills fetch at Build.

### Added
- `.cursor/environment.json` runs `.cursor/install.sh` and `.cursor/start.sh`
- `.cursor/install.sh` provisions a cold image. On a warm snapshot it skips apt, ruby-build, db:prepare, and tailwind when Ruby, bundle, and Postgres are already usable. A skippable provision failure does not fail the Build. Fetch-skills always runs last
- `.cursor/fetch-skills.sh` downloads recording-studio skills and plugin rules. It never clones the plugin or vendors `SKILL.md`
- `.cursor/start.sh` starts PostgreSQL on each environment boot
- [Cursor skills in Cloud Agents](docs/cursor-skills.md)

### Fixed
- Dummy Tailwind `@source` paths now scan `vendor/bundle` RecordingStudio views and Flatpack `.rb` / `.erb` components so host CSS includes button, table, card, and page-nav utilities

### Upgrade Notes
- No host or schema changes. Rebuild the Cloud Agent environment with Draft off so Build loads the pack

## [0.2.0] - 2026-08-21

### Breaking
- Replaced `RecordingStudio::RecordingStudioOrder` snapshot recordables, named lists, and owner-scoped order trees with sibling position on `recording_studio_recordings`
- Enablement is now `include RecordingStudio::Capabilities::Orderable.to(**opts)` on parent recordables. The `OrderableRecordable` / `recording_studio_order_group` DSL is gone
- Runtime dependency is now RecordingStudio `~> 4.1` (tested with `4.1.0`). `recording_studio_accessible` is no longer a required gem dependency
- Required Ruby is `>= 3.3`

### Added
- `recording_studio_orderable_position` column and sibling reorder APIs on `RecordingStudio::Recording`
- Optional `log_event!` reorder history on the parent recording
- Dummy app on Recording Studio core default layout and Flatpack

### Removed
- `RecordingStudioOrder` recordable, mounted named-list product surface, and committed coverage artifacts

### Upgrade Notes
- Host apps must move to RecordingStudio `~> 4.1` with this gem
- Enable Orderable on parent recordables with `RecordingStudio::Capabilities::Orderable.to(allows: [...])`
- Run `bin/rails generate recording_studio_orderable:migrations` and `bin/rails db:migrate`
- Do not keep or migrate snapshot order recordables; sibling position is the supported model

## [0.1.1] - 2026-04-28

### Changed
- Bumped the dummy app FlatPack dependency from `0.1.2` to `0.1.33` and pinned it by tag in `test/dummy/Gemfile`

## [0.1.0] - 2025-12-04

### Added
- Initial release
- Rails mountable engine structure
- PostgreSQL with UUID primary keys support
- TailwindCSS v4 integration
- GitHub Codespaces devcontainer configuration
- Docker Compose setup with PostgreSQL and Redis
- Install generator for host applications
- Comprehensive README and documentation
- Basic test suite with Minitest

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_orderable/compare/v0.4.4...HEAD
[0.4.4]: https://github.com/bowerbird-app/RecordingStudio_orderable/compare/v0.4.3...v0.4.4
[0.4.3]: https://github.com/bowerbird-app/RecordingStudio_orderable/compare/v0.4.2...v0.4.3
[0.4.2]: https://github.com/bowerbird-app/RecordingStudio_orderable/compare/v0.4.1...v0.4.2
[0.4.1]: https://github.com/bowerbird-app/RecordingStudio_orderable/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/bowerbird-app/RecordingStudio_orderable/compare/v0.3.1...v0.4.0
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_orderable/compare/v0.2.3...v0.3.0
[0.2.3]: https://github.com/bowerbird-app/RecordingStudio_orderable/compare/v0.2.2...v0.2.3
[0.2.2]: https://github.com/bowerbird-app/RecordingStudio_orderable/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/bowerbird-app/RecordingStudio_orderable/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_orderable/releases/tag/0.2.0
[0.1.1]: https://github.com/bowerbird-app/RecordingStudio_orderable/releases/tag/v0.1.1
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_orderable/releases/tag/v0.1.0
