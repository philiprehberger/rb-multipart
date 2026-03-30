# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-03-29

### Added
- Content-Type guessing via `MimeTypes.lookup(filename)` with 100+ built-in extension mappings
- Auto-detect MIME type from filename when `content_type:` is not provided in `file()` calls
- Streaming file support: `Builder#file` now accepts IO objects (StringIO, File, etc.) in addition to file paths
- Multipart parsing via `Multipart.parse(body, content_type:)` to parse incoming multipart/form-data bodies
- `Parser` class for parsing raw multipart bodies into `Part` objects
- `Part#body` accessor as alias for `Part#value`
- GitHub issue templates, PR template, and Dependabot configuration

## [0.1.3] - 2026-03-24

### Fixed
- Remove inline comments from Development section to match template

## [0.1.2] - 2026-03-22

### Changed
- Expanded test coverage to 30+ examples covering edge cases, error paths, and boundary conditions

## [0.1.1] - 2026-03-22

### Changed
- Version bump for republishing

## [0.1.0] - 2026-03-22

### Added
- Initial release
- DSL builder for constructing multipart/form-data bodies
- Text field support via `field` method
- File upload support via `file` method with content type
- Automatic boundary generation
- Content-Type header generation with boundary
