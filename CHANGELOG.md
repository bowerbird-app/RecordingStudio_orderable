# 0.13.3 (Unreleased)

- Added: Drag-save notification/event contract for orderable UIs. Host apps can now opt into custom event notifications (`recordingstudio:order:updated`) instead of the default revisit-based flash notice flow.
- Updated: Documentation in README, INSTALLING.md, CONFIGURATION.md, and dummy app docs to explain notification/event split and JS integration pattern.
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Renamed the engine to `recording_studio_orderable`
- Replaced the template sample addon with `RecordingStudio::RecordingStudioOrder` ordering support
- Added Folder + Page ordering demo data and FlatPack table UI in the dummy app
- Bumped the dummy app FlatPack dependency from `v0.1.33` to `v0.1.53` and hardened `current_recording` for plain delegate recordings

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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_orderable/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/bowerbird-app/RecordingStudio_orderable/releases/tag/v0.1.1
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_orderable/releases/tag/v0.1.0
