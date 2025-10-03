# GEMINI Playbook

## Quick Context
- PungentRoots is a SwiftUI iOS app that performs on-device Vision OCR and dictionary-based detection to flag allium ingredients.
- The capture-to-verdict pipeline flows through `LiveCaptureController`, `TextAcquisitionService`, and `DetectionEngine`, culminating in SwiftUI overlays within `Views/`.
- Data models under `Models/` preserve normalized UTF-16 ranges that downstream highlights and persistence rely on.

## Key Files to Inspect First
1. `PungentRoots/Camera/LiveCaptureController.swift` – camera session coordination, readiness heuristics, throttling logic.
2. `PungentRoots/OCR/OCRConfiguration.swift` & `Services/TextAcquisitionService.swift` – Vision request configuration and normalization stack.
3. `PungentRoots/Detection/DetectionEngine.swift` & `Detection/DetectDictionary.swift` – rule passes, scoring constants, bundled dictionary loading.
4. `PungentRoots/Views/` (notably `DetectionResultView.swift`) – renders verdict cards, highlights, and accessibility messaging.
5. `PungentRootsTests/` – reference usage of Apple’s `Testing` framework for behavior-driven coverage.

## Workflow Expectations
- Map the full capture → normalization → detection → presentation journey before proposing edits; note cross-module effects explicitly.
- Pair feature work with automated tests or spell out manual reproduction steps and simulator targets when automation is impractical.
- Keep the detection dictionary alphabetized and versioned; document ingredient rationale inside commits/PRs.

## Response & CLI Style
- Deliver succinct bullet-point reasoning followed by shell-friendly command snippets in ```bash``` fences when sharing workflows or validation steps.
- Surface exact commands for builds/tests (`Scripts/run-tests.sh`, `xcodebuild` invocations) and annotate expected outputs or follow-up actions.
- Highlight concurrency considerations (actors, queues) and accessibility checks whenever UI flows are touched.

## Quality & Safety Checks
- Reinforce 4-space indentation, `guard`-first early exits, and <80-line functions; suggest extracting helpers into `Utilities/` when logic expands.
- Reject proposals that introduce networking, cloud processing, or logging of sensitive OCR text—processing must remain on-device.
- Mirror the guidance level found in `CLAUDE.md` so agent docs stay synchronized.
