# Repository Guidelines

## Project Structure & Module Organization
- `PungentRoots/`: SwiftUI app sources.
  - `PungentRootsApp.swift`: bootstraps the dictionary and shares services through `AppEnvironment`.
  - `Camera/`: `LiveCaptureController` wraps `AVCaptureSession` + Vision OCR auto-capture, including zoom/readiness heuristics and capture throttling.
  - `OCR/`: `OCRConfiguration` presets Vision request tuning; `DocumentCameraView` hosts VisionKit-based still capture.
  - `Services/`: `AppEnvironment` wires `DetectionEngine`, `TextAcquisitionService`, and shared normalizer instances.
  - `Detection/`: dictionary models (`DetectDictionary`), rule-based `DetectionEngine`, and `DetectionScoring` constants.
  - `Utilities/`: normalization and regex helpers used across detection/OCR layers.
  - `Models/`: SwiftData-compatible `Scan` record plus supporting enums and match structs.
  - `Views/`: SwiftUI presentation (camera overlays, detection cards, settings, reporting) that consume environment services.
  - `Resources/`: bundled assets such as `pungent_roots_dictionary.json` (keep versioned and alphabetized by locale group).
- `PungentRootsTests/`: unit targets built with Apple’s new `Testing` framework—cover normalization, detection scoring, and service fixtures.
- `PungentRootsUITests/`: UI automation and accessibility assertions.
- `Scripts/`: automation helpers (e.g. `run-tests.sh` wraps `xcodebuild` and simulator shutdown for CI/local consistency).

## Build, Test, and Development Commands
- `xed .` or `open PungentRoots.xcodeproj`: open the project in Xcode 15+ (iOS 17+ SDK recommended).
- `xcodebuild -scheme PungentRoots -destination "platform=iOS Simulator,OS=18.5,name=iPhone 16 Pro" build`: deterministic CI build.
- `xcodebuild test -scheme PungentRoots -destination "platform=iOS Simulator,OS=18.5,name=iPhone 16 Pro"`: run all targets, including `Testing` suites.
- `Scripts/run-tests.sh`: preferred wrapper for local/CI runs; executes the command above and shuts down simulators afterward to conserve resources.
- `swift test`: keep parity once SwiftPM packages or previews are extracted.

## Coding Style & Naming Conventions
- Swift source: 4-space indentation, avoid trailing whitespace, prefer `guard` for early exits, keep functions <80 lines.
- Types use UpperCamelCase (`ScanResultView`); methods/properties use lowerCamelCase (`recognizeText`).
- Organize files by feature and mirror that layout under test targets.
- Use `///` doc comments for non-obvious logic; avoid inline chatter.
- Camera/OCR work occurs off the main actor—hop back to `DispatchQueue.main`/`@MainActor` when mutating observable state.

## Testing Guidelines
- Default to the `Testing` framework (`import Testing`) with structured `@Test` functions; mark UI-bound cases `@MainActor`.
- Store deterministic fixtures alongside tests (dictionary snapshots, normalization samples, OCR mocks). Keep them lightweight and language-specific.
- Name tests with behavior-focused phrases (`@Test("Onion powder triggers contains verdict")`).
- Maintain ≥90% coverage on detection utilities and add regression tests whenever dictionaries, scoring thresholds, or OCR heuristics change.
- For camera/OCR changes, include at least one integration test (or documented manual runbook) that exercises `LiveCaptureController` readiness transitions.

## Documentation & Process Notes
- Update `README.md` when workflows or architecture entry points change; keep the developer summary concise but actionable.
- Maintain `AGENTS.md`, `GEMINI.md`, and `CLAUDE.md` in sync with repository structure. Claude and Gemini guides must remain equivalently detailed, each calling out their agent-specific best practices (Claude code snippets, Gemini CLI responses).
- The detection dictionary is versioned—bump the JSON `version` string and note the rationale in commit/PR descriptions when editing ingredients.
- Record manual validation steps for camera/OCR tuning in `PLAN.md` when automation is impractical.

## Commit & Pull Request Guidelines
- Write imperative, present-tense summaries (`Add detection engine service`) with optional scope tags (`[Detection]`); keep the first line ≤72 chars.
- Reference issues or Notion tasks in the body, and list validation evidence (`xcodebuild test`, simulator screenshots) before requesting review.
- PRs must include: purpose summary, targeted screens/devices, accessibility considerations, and any new assets/fixtures as separate commits when practical.
- Before merging, confirm `AGENTS.md`, `PLAN.md`, and agent guides reflect structural or process updates.

## Documentation Resources
- Use the context7 tool to pull the latest Apple documentation—the Vision, AVFoundation, and SwiftUI APIs evolve quickly and recent changes may not be in cached references.
- Capture citation links when quoting API guidance so reviewers can verify assumptions.

## Security & Privacy Notes
- Processing stays on-device; do not introduce network calls without explicit approval.
- Strip sensitive text from debug logs and dispose of intermediate scan images after persistence completes.
