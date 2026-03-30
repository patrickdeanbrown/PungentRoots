# PungentRoots Validation Plan

## Current Architecture Checkpoints
- `ContentView` is a thin shell that owns `ScanFlowModel`.
- `ScanFlowModel` handles capture orchestration, async analysis, cancellation, rescan, and UI-test preview hooks.
- `AppEnvironment` returns typed `ScanAnalysis` values.
- Shared capture-domain types live in `PungentRoots/Camera/CaptureTypes.swift`.
- Liquid Glass is applied selectively through `PungentRoots/Views/AdaptiveGlass.swift` and gated behind `iOS 26` availability checks.

## Automated Baseline
- Run `Scripts/run-tests.sh` before and after substantive changes.
- Keep unit coverage in `PungentRootsTests/` for analysis typing, flow-model transitions, overlay severity mapping, and detection behavior.
- Keep scenario UI coverage in `PungentRootsUITests/` for:
  - settings presentation
  - transcript disclosure
  - rescan returning to the capture state
  - accessibility-size rendering

## Manual Validation Matrix
- **Data Scanner path on supported hardware**
  - Environment: iPhone simulator or device with `DataScannerViewController` support and the Data Scanner preference enabled.
  - Steps: Launch the app, present a clear ingredient label, wait for capture, verify the status badge transitions through scanning/processing, then inspect the verdict card.
  - Expected: Capture happens without showing the legacy fallback UI, OCR completes, verdict and highlights appear, and rescan resumes live scanning.
- **Forced legacy path**
  - Environment: Disable the Data Scanner setting or run on unsupported hardware.
  - Steps: Launch the app, confirm the legacy capture path starts, scan an ingredient label, then rescan.
  - Expected: Legacy readiness guidance appears, capture completes, result rendering matches the Data Scanner path, and rescan returns to the live preview.
- **Camera permission denied or unavailable**
  - Environment: Fresh simulator/device with camera permission denied, or an environment without camera availability.
  - Steps: Launch the app and attempt to enter the scanning flow.
  - Expected: The app surfaces a clear error state, does not crash, and remains navigable so the user can recover after changing permissions.
- **iOS 26 Liquid Glass presentation**
  - Environment: iOS 26 simulator or device.
  - Steps: Inspect the settings header, status badge cluster, and primary result action.
  - Expected: Glass treatments appear only on compact chrome, remain legible over backgrounds, and do not reduce transcript readability or preview clarity.
- **Pre-iOS 26 fallback presentation**
  - Environment: iOS 18.5 or 18.6 simulator.
  - Steps: Repeat the same UI checks used for the iOS 26 pass.
  - Expected: Material-based cards and buttons render correctly, layout stays stable, and no iOS 26-only API usage leaks into runtime.

## Notes
- If automation cannot cover a capture or OCR regression, add the reproduction steps here in the same format.
- Update this file whenever device coverage, permission handling, or platform-specific fallback expectations change.
