# PungentRoots

## Developer Summary
PungentRoots is a SwiftUI iOS app that screens ingredient labels for pungent-root ingredients entirely on-device. The app targets `iOS 18.5+`, prefers VisionKit’s `DataScannerViewController` on supported hardware, and falls back to a legacy `AVCaptureSession` + Vision OCR path when needed. Detection stays rule-based and local, while the UI uses a typed scan flow model and availability-gated iOS 26 styling improvements rather than platform-specific forks.

## Architecture At a Glance
1. **App bootstrap**: `PungentRootsApp` creates the live `AppEnvironment` and injects it into the root scene.
2. **Screen orchestration**: `ContentView` remains a thin shell. `ScanFlowModel` owns capture lifecycle, async analysis, cancellation, error presentation, transcript disclosure state, and rescan behavior.
3. **Capture pipeline**: `AutoCaptureController` selects between the VisionKit scanner and the legacy `LiveCaptureController`. Both paths publish shared `CapturePayload`, `CaptureState`, and `CaptureReadiness` values so the UI does not depend on legacy controller details.
4. **OCR + detection**: `TextAcquisitionService` normalizes captured text and `AppEnvironment` returns a typed `ScanAnalysis` from sync and async analysis entrypoints.
5. **Presentation**: `ScanCameraModuleView`, `ScanResultSectionView`, `DetectionResultView`, and supporting views keep the UI modular and Dynamic Type-friendly. `AdaptiveGlass.swift` applies Liquid Glass selectively on iOS 26 and falls back to material styling below that.
6. **Observability**: `MetricReporter` subscribes to MetricKit and detection work remains instrumented for performance tracking.

## Local Development
- Open `PungentRoots.xcodeproj` in Xcode or run `xed .`.
- Preferred build:
  - `xcodebuild -scheme PungentRoots -destination "platform=iOS Simulator,OS=18.6,name=iPhone 16 Pro" build`
- Preferred full test pass:
  - `Scripts/run-tests.sh`
- Useful UI-test launch arguments:
  - `--ui-test-disable-capture`
  - `--ui-test-preview-result`
- Dictionary source lives at `PungentRoots/Resources/pungent_roots_dictionary.json`; keep entries sorted and bump the embedded `version` field when editing it.

## Contribution Notes
- Keep `ContentView` thin and move new screen orchestration into `ScanFlowModel`.
- Use `ScanAnalysis` for result plumbing instead of ad hoc tuples.
- Keep shared UI state on `CapturePayload`, `CaptureState`, and `CaptureReadiness` rather than leaking `LiveCaptureController` internals upward.
- Treat iOS 26 UI APIs as additive. All Liquid Glass usage must have lower-version fallbacks.
- When changing capture behavior, verify both supported Data Scanner devices and the forced-legacy path.
- When changing detection or normalization, add or update `Testing`-framework coverage and preserve normalized UTF-16 range behavior for highlights.

## Documentation Ownership
- `AGENTS.md` is the canonical repo guide for coding agents.
- `CLAUDE.md` and `GEMINI.md` are intentionally thin wrappers.
- `PLAN.md` holds the manual validation matrix for capture, permissions, and platform fallback checks.

## License
PungentRoots is distributed under the terms of the [MIT License](LICENSE).
