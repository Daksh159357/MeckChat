# Contributing to MeckChat

Thank you for your interest in contributing to MeckChat!

## Architectural Architecture Rules
1. **Rust Core**: All core networking, WireGuard configuration, MQTT signaling, crypto key derivation, file transfer engine, and SQLite database logic reside in `core/rust/`.
2. **Flutter UI**: The user interface, state management, and platform UI bindings reside in `apps/flutter/`.
3. **No Data on HiveMQ**: Never route application payload data (messages, file chunks, audio/video streams) through MQTT. HiveMQ is exclusively for presence and peer WireGuard signaling.

## Development Workflow
All automated builds, linting, unit tests, and cross-platform compilation run via **GitHub Actions**.

### Local Code Quality Checks
Before submitting a pull request, ensure:
```bash
# Rust core linting & tests
cd core/rust
cargo check
cargo clippy
cargo test

# Flutter application check & tests
cd apps/flutter
flutter analyze
flutter test
```

## Pull Request Guidelines
- Write descriptive commit messages.
- Ensure all CI tests pass in GitHub Actions.
- Update protocol documentation in `protocol/` if MQTT topics or binary wire formats are changed.
