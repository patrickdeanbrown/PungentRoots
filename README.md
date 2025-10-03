# PungentRoots

## Developer Summary
PungentRoots is a SwiftUI iOS app that screens ingredient labels for allium-containing terms entirely on-device. Live capture uses `AVCaptureSession` plus Vision OCR to stream text into a rule-based detection engine that scores risk levels and surfaces accessibility-friendly verdicts to the UI. The codebase is organized by feature (camera/OCR, detection, services, views) so each module can evolve independently while sharing normalization utilities.

## Architecture at a Glance
1. **App bootstrap** – `PungentRootsApp` loads the bundled dictionary and injects shared services through `AppEnvironment`.
2. **Capture + OCR** – `LiveCaptureController` steers camera authorization, zoom heuristics, and `VNRecognizeTextRequest` scheduling; `TextAcquisitionService` and `OCRConfiguration` normalize text for detection.
3. **Detection Engine** – `DetectionEngine` consults `DetectDictionary` to run exact, synonym, pattern, ambiguous, and fuzzy passes that yield `DetectionResult` aggregates.
4. **Models & Persistence** – Types in `Models/` (`Scan`, `Match`, enums) mirror detection payloads and keep highlight ranges consistent for SwiftUI overlays.
5. **Presentation** – SwiftUI views under `Views/` render camera overlays, result cards, settings, and reporting affordances while respecting environment services.

## Local Development
- Open `PungentRoots.xcodeproj` in Xcode 15+ (iOS 17+ SDK recommended) or run `xed .`.
- Preferred build: `xcodebuild -scheme PungentRoots -destination "platform=iOS Simulator,OS=18.5,name=iPhone 16 Pro" build`.
- Preferred full test pass: `Scripts/run-tests.sh` (wraps `xcodebuild test` and simulator shutdown for reproducibility).
- Dictionary source lives at `PungentRoots/Resources/pungent_roots_dictionary.json`; keep entries sorted, localized groupings intact, and bump the embedded `version` field when editing.

## Contribution Notes
- Detection assumes normalized UTF-16 ranges—when adjusting tokenizers or matchers, preserve range math to keep highlights accurate.
- Camera and OCR work run off the main actor; funnel UI mutations back through `DispatchQueue.main`/`@MainActor` to avoid state races.
- When expanding verdicts or UI states, update `DetectionResultView` (and related overlays) plus add coverage under `PungentRootsTests/` or document manual validation for camera heuristics.
