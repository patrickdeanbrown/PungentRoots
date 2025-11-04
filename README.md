# PungentRoots

PungentRoots is a SwiftUI iOS app that scans ingredient labels to detect allium ingredients (onions, garlic, shallots, leeks, chives, scallions) entirely on-device using Vision OCR and rule-based detection.

## Features

### Core Functionality
- **Real-time camera scanning** with automatic capture when text quality is sufficient
- **On-device processing** – no network required, complete privacy
- **Multilingual detection** – identifies allium terms in English, Spanish, French, Italian, German, Portuguese, Japanese, Mandarin, and Korean
- **Three-tier verdicts** – Safe / Needs Review / Contains with clear visual indicators
- **Smart detection engine** – multi-pass system with exact matching, pattern detection, fuzzy matching (OCR error correction), and ambiguous term flagging

### Camera & Capture
- **Dual scanner system** – VisionKit DataScanner (iOS 16+) with AVFoundation fallback for older devices
- **Intelligent readiness feedback** – progressive states (Too Far → Almost Ready → Ready)
- **Configurable zoom** – 1.0x to 5.0x with device-specific limits
- **Quality gates** – minimum text length, line count, and confidence thresholds

### User Experience
- **Visual highlights** – color-coded bounding boxes and text highlighting showing detected ingredients
- **Accessibility support** – VoiceOver labels, haptic feedback, Dynamic Type support
- **Capture tips** – built-in guidance for optimal scanning results
- **Privacy-first** – all text processing stays on device, privacy manifest included

## Architecture

The app follows a clear data flow: Camera Capture → OCR → Text Normalization → Detection → Presentation

1. **Capture** – `AutoCaptureController` selects VisionKit or AVFoundation based on device capability
2. **OCR** – `TextAcquisitionService` + `OCRConfiguration` extract and normalize text from frames
3. **Detection** – `DetectionEngine` applies multi-pass rules (exact, pattern, fuzzy, ambiguous) using `DetectDictionary`
4. **Presentation** – SwiftUI views display results with color-coded highlights and accessibility support
5. **Services** – `AppEnvironment` wires dependencies; `MetricReporter` tracks performance

## Development

### Building & Testing
```bash
xed .  # Open in Xcode 15+
xcodebuild -scheme PungentRoots -destination "platform=iOS Simulator,OS=18.5,name=iPhone 16 Pro" build
Scripts/run-tests.sh  # Run full test suite with simulator cleanup
```

### Key Directories
- `PungentRoots/Camera/` – Dual scanner implementation (VisionKit + AVFoundation)
- `PungentRoots/Detection/` – Detection engine, scoring, and dictionary loading
- `PungentRoots/OCR/` – Vision configuration and text normalization
- `PungentRoots/Views/` – SwiftUI presentation layer
- `PungentRoots/Resources/pungent_roots_dictionary.json` – Detection terms (versioned, alphabetized)
- `PungentRootsTests/` – Apple Testing framework test suites

### Contributing
- Preserve UTF-16 ranges when modifying text processing to maintain highlight accuracy
- Use `@MainActor` for UI updates; detection runs async via `AppEnvironment.analyzeAsync`
- Bump dictionary `version` field when editing terms and document changes in commit messages
- Add tests for detection logic changes; document manual validation for camera/OCR tuning

See `AGENTS.md` for detailed coding standards and workflow guidelines.

## License
PungentRoots is distributed under the terms of the [MIT License](LICENSE).
