# Repository Guidelines

## Project Structure & Module Organization
- `PungentRoots/`: SwiftUI app sources (entry in `PungentRootsApp.swift`, UI in `ContentView.swift`, feature folders like `Detection/`, `Services/`, `Views/` house the auto-capture controller, rule engine, OCR pipeline, and settings UI).
- `PungentRootsTests/`: unit targets built with Apple’s new `Testing` framework—use it for rule engine, normalization, and service fixtures.
- `PungentRootsUITests/`: UI automation and accessibility assertions.
- `Assets.xcassets/`: app imagery, color sets, and future brand tokens; keep generated thumbnails out of source control.
- `Scripts/`: automation helpers (e.g. `run-tests.sh` wraps `xcodebuild` and simulator shutdown for CI/local consistency).

## Build, Test, and Development Commands
- `xed .` or `open PungentRoots.xcodeproj`: open the project in Xcode.
- `xcodebuild -scheme PungentRoots -destination "platform=iOS Simulator,OS=18.5,name=iPhone 16 Pro" build`: deterministic CI build.
- `xcodebuild test -scheme PungentRoots -destination "platform=iOS Simulator,OS=18.5,name=iPhone 16 Pro"`: run all targets, including `Testing` suites.
- `Scripts/run-tests.sh`: preferred wrapper for local/CI runs; executes the command above and shuts down simulators afterward to conserve resources.
- `swift test`: keep parity once SwiftPM packages or previews are extracted.

## Coding Style & Naming Conventions
- Swift source: 4-space indentation, avoid trailing whitespace, prefer `guard` for early exits, keep functions <80 lines.
- Types use UpperCamelCase (`ScanResultView`); methods/properties use lowerCamelCase (`recognizeText`).
- Organize files by feature and mirror that layout under test targets.
- Use `///` doc comments for non-obvious logic; avoid inline chatter.

## Testing Guidelines
- Default to the `Testing` framework (`import Testing`) with structured `@Test` functions; mark UI-bound cases `@MainActor`.
- Store deterministic fixtures alongside tests (`DetectionFixtures.swift`, normalization/OCR helpers). Keep them lightweight and language-specific.
- Name tests with behavior-focused phrases (`@Test("Onion powder triggers contains verdict")`).
- Maintain ≥90% coverage on detection utilities and add regression tests whenever dictionaries or scoring rules change.

## Commit & Pull Request Guidelines
- Write imperative, present-tense summaries (`Add detection engine service`) with optional scope tags (`[Detection]`); keep the first line ≤72 chars.
- Reference issues or Notion tasks in the body, and list validation evidence (`xcodebuild test`, simulator screenshots) before requesting review.
- PRs must include: purpose summary, targeted screens/devices, accessibility considerations, and any new assets/fixtures as separate commits when practical.
- Before merging, confirm `AGENTS.md` and `PLAN.md` reflect structural or process updates.

## Documentation Resources
- Use the context7 tool to pull the latest Apple documentation—the Vision, AVFoundation, and SwiftUI APIs evolve quickly and recent changes may not be in cached references.
- Capture citation links when quoting API guidance so reviewers can verify assumptions.

## Security & Privacy Notes
- Processing stays on-device; do not introduce network calls without explicit approval.
- Strip sensitive text from debug logs and dispose of intermediate scan images after persistence completes.
