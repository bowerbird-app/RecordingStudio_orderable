# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- Dummy Tailwind `@source` paths now scan `vendor/bundle` RecordingStudio views and Flatpack `.rb` / `.erb` components so host CSS includes button, table, card, and page-nav utilities

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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_orderable/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_orderable/releases/tag/v0.2.0
[0.1.1]: https://github.com/bowerbird-app/RecordingStudio_orderable/releases/tag/v0.1.1
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_orderable/releases/tag/v0.1.0
