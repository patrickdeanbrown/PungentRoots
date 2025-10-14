# PungentRoots v0.1 Implementation Plan

## 1. Product Goals
- Deliver a trustworthy on-device tool that flags pungent-root ingredients (garlic, onion, shallot, leek, chive, scallion) in photos or pasted text within the target performance budgets.
- Provide transparent explanations, risk scoring, and a history that builds user confidence while preserving privacy.
- Lay foundations for extensibility (additional languages, custom rules, share extensions) without compromising the MVP timeline.

## 2. Guiding Principles & Apple Best Practices
- Keep all processing on-device and isolate state using SwiftUI environment injection so views stay declarative and testable.[^swiftui-state]
- Keep scan data ephemeral; rely on in-memory state and detection services rather than persisted records.[^swiftui-state]
- Respect Apple’s Human Interface Guidelines by pairing color with clear iconography and typography, delivering accessible feedback across light/dark modes.[^hig-color]
- Prepare Vision and VisionKit requests up front, tune them for accuracy versus speed, and scope work to regions of interest to stay within latency targets.[^vision-ocr][^visionkit]
- Tokenize text with NaturalLanguage to reduce custom parsing logic and improve resilience to edge cases like Unicode punctuation.[^nltagger]

## 3. MVP Scope Check
- **Input:** Auto-capture defaults to VisionKit’s `DataScannerViewController` with a fallback `AVCaptureSession` pipeline for unsupported devices, plus a single rescan affordance for manual retries.
- **Detection:** Normalize text, run deterministic matching (exact/synonym/pattern/fuzzy), and maintain internal scoring to inform guidance while surfacing match lists only.
- **Output:** Inline match list with red/yellow severity, optional transcript toggle, and caméra tips encouraging fresh rescans (no persistent history).
- **Persistence:** Keep captures ephemeral; explore opt-in history later if user demand returns.

## 4. Architecture Overview
1. **Input Layer**
   - Route capture through `AutoCaptureController`, which prefers VisionKit’s `DataScannerViewController` and gracefully falls back to the legacy `LiveCaptureController` (AVFoundation + Vision) for unsupported hardware.
   - Provide pinch/slider zoom, macro-focused configuration, and optional rescan control once results are shown.
2. **OCR & Normalization Service**
   - `TextAcquisitionService` orchestrates OCR tasks, returns normalized text with source metadata, and strips hyphen breaks, bullet characters, and problematic whitespace.
3. **Detection Engine**
   - Stateless service that consumes normalized text plus bundled dictionary JSON, emits matches with ranges and rationale, and scores risk per the weighting table.
4. **Persistence Layer**
   - Auto-capture controller manages camera state on a background queue while results stay on the main actor for UI updates.
5. **Presentation Layer**
   - SwiftUI navigation stack: Home (actions + history) → Capture/Paste flows → Result detail. Derived view models expose immutable state to views, with mutation isolated to services.

## 5. Text Capture and OCR
- Prefer VisionKit’s Data Scanner for live text detection; configure the scanner to highlight guidance, limit captures to a single ingredient block, and surface readiness feedback in the UI.
- When Data Scanner isn’t available, configure a reusable `VNRecognizeTextRequest` with `.accurate` recognition and language correction, falling back to `.fast` for degraded images.[^vision-ocr]
- Populate `recognitionLanguages` with `Locale.Language("en-US")` initially and expose a setting stub for future locales; rely on `supportedRecognitionLanguages` to validate availability.[^vision-ocr]
- Run OCR on a background task; return results via `MainActor` isolation to satisfy Vision threading requirements and update UI state safely.

## 6. Text Normalization & Tokenization
- Normalize using Unicode NFKC, lowercase, collapse whitespace, rejoin hyphenated breaks, and strip punctuation that splits tokens unexpectedly.
- Tokenize using `NLTagger(tagSchemes: [.tokenType])` with `.word` units and `.omitWhitespace` so the detection engine operates on consistent tokens regardless of input formatting.[^nltagger]
- Maintain UTF-16 ranges for matches to stay compatible with SwiftUI attributed strings.

## 7. Detection Engine
- Load the bundled dictionary JSON into a cached `DetectDictionary` struct at launch; watch for decode failures and surface a non-blocking alert path.
- Exact & synonym passes use regex with word boundaries; patterns handle suffixes like powder/salt/extract; ambiguous list triggers caution-tier matches; fuzzy pass applies Levenshtein distance thresholds for short vs. long tokens.
- Accumulate scores by severity, cap ambiguous contributions, and derive verdict tiers (`safe` <0.3, `needsReview` <0.8, `contains` ≥0.8). Persist match notes for UI explanations.
- Structure the engine for eventual replacements (e.g., Aho–Corasick) without changing the public API.

## 8. UI Modernization Roadmap (Plan C)
- **Audit & Baseline**
  - Capture current camera module, result card, and settings layouts in light/dark with Dynamic Type XXL.
  - Document spacing, typography, and accessibility gaps; track findings for follow-up.
- **Visual Refresh**
  - Replace custom gradients with `Material`/`GlassBackgroundStyle` and semantic system colors.
  - Adopt `ViewThatFits`/adaptive stacks to accommodate compact vs. regular size classes.
  - Update toolbar/navigation to large-title patterns with contextual trailing actions.
- **Accessibility & Localization**
  - Add descriptive accessibility labels, hints, and traits to overlays and status badges.
  - Localize newly surfaced scanner guidance strings and regenerate `Localizable.strings`.
  - Extend UI tests to cover Dynamic Type, VoiceOver focus, and refreshed snapshots.
- **Validation**
  - Smoke-test on simulator/device, verifying haptics and animations meet HIG guidance.
  - Update README/AGENTS with refreshed UI descriptions and screenshots.

## 9. Detection & Services Modernization (Plan D)
- **Async Pipeline**
  - Convert detection entrypoints to async using `Task` and cooperative cancellation between camera and detection layers.
  - Maintain sync wrappers for backward compatibility while migrating tests.
- **Instrumentation**
  - Add `os.Logger` signposts for acquisition, normalization, and detection stages.
  - Integrate `MetricKit` to capture latency and thermal metrics; surface dashboards for regression tracking.
- **Text Processing Enhancements**
  - Prototype `NaturalLanguage` tokenization; benchmark accuracy/performance against the regex pipeline.
  - Externalize fuzzy thresholds to configuration for easier experimentation.
- **Testing & QA**
  - Expand `Testing` suites with async scenarios and additional fixtures.
  - Document manual QA steps for detection latency/accuracy across sample labels.
  - Enhance Scripts/run-tests.sh with optional async performance checks.

## 8. Data Model & Persistence
- Implement the provided `Scan` model with `@Model`, apply `@Attribute(.unique)` to `id`, and preserve user verdict overrides by marking key fields as `.preserveValueOnDeletion` when appropriate.[^swiftdata-model]
- Store embedded `Match` structs in the `Scan` record to simplify fetches; include derived properties (e.g., `defaultVerdict`) in view models to keep models lean.
- Inject `ModelContext` via `.modelContainer(for:)` at `App` root to share across scenes and ensure one source of truth for SwiftUI views.[^swiftui-state]
- Provide lightweight migrations for dictionary evolve cases by versioning JSON and storing the version with each scan for analytics.

## 9. SwiftUI Experience
- Compose screens with `NavigationStack` + `NavigationSplitView` on iPad/Mac for history browsing, keeping detail view states synchronized with `@State` and `List` selection patterns recommended by SwiftUI docs.[^swiftui-state]
- Drive view state with observable view models annotated using `@Observable` (or `@StateObject` where indirection is needed) to keep mutation controlled and preview-friendly.
- Annotate highlights using attributed strings, ensuring VoiceOver exposes match context via `accessibilityAttributedLabel` and not color alone.[^hig-color]
- Provide toggles and verdict chips that adapt to Dynamic Type and remain legible in high contrast settings.

## 10. Accessibility, Feedback, and Trust
- Announce verdict changes via `accessibilityAnnouncement` and pair them with subtle haptics (e.g., `.warning`) so feedback is multimodal.
- Include copy clarifying that “Needs Review” items may mask alliums; reference ambiguous match notes directly from the detection engine.
- Respect `Reduce Motion` by gating animations and provide secondary indicators (icons, text) wherever color coding is used.[^hig-color]

## 11. Testing & Quality Gates
- Unit-test normalization, detection scoring, and fuzzy matching with curated fixtures (20 contains, 20 ambiguous, 20 safe) to guarantee recall ≥0.98 for definite terms and precision ≥0.9 for `.contains` verdict.
- Write integration tests covering OCR + detection using sample images; assert normalized strings include expected tokens with at most one edit distance variance.
- Add SwiftUI snapshot or accessibility tests for the result screen to ensure highlight readability under Dynamic Type and dark mode.
- Run async OCR tests on a background queue to surface threading regressions early.

## 12. Privacy, Permissions, and Failure Modes
- Present camera and photo-library permission copy emphasizing on-device processing and zero network use.
- Gracefully degrade: if OCR fails, offer manual text entry with guidance; if detection finds only ambiguous terms, prompt the user to review and override verdict.
- Cache scans locally only with explicit user opt-in for saving; expose a quick “Clear History” action that issues a batch delete on the main actor.

## 13. Delivery Timeline (10 Working Days + Buffer)
1. **Day 1–2:** Auto-capture controller scaffolding, camera authorization flow, detection integration, and loading/error states.
2. **Day 3–4:** Zoom/macro tuning, alignment guides, and device tests across lighting scenarios.
3. **Day 5:** Result card refinements, transcript toggle, color tokens, and motion cues (respecting Reduce Motion).
4. **Day 6:** Accessibility pass (contrast, Dynamic Type, VoiceOver announcements) and logging instrumentation.
5. **Day 7:** Error state copy, resiliency for capture failures, and guidance updates.
6. **Day 8–9:** Unit + integration tests, sample image fixtures, automation hooks (CI script skeleton).
7. **Day 10:** Polish, documentation, App Store asset placeholders, prepare TestFlight build.
8. **Days 11–14 (buffer):** Stabilization, localization groundwork (dictionary versioning), release checklist.

## 14. Stretch Roadmap (Post-v0.1)
- Household rule overrides with shareable JSON exports (respecting on-device storage).
- Share extension for Safari/Photos text scanning using the same detection engine.
- Barcode lookup with optional consent-based network requests.
- Additional language packs (ES/FR/IT) once dictionary translation pipeline is ready.
- Active rectangle detection and optional CreateML-backed classifier to complement deterministic rules.

## References
[^swiftui-state]: Managing shared state with SwiftUI environment and property wrappers. <https://github.com/zhangyu1818/swiftui.md/blob/main/swiftui-model%20data-managing%20model%20data%20in%20your%20app.md#_snippet_10>
[^swiftdata-model]: SwiftData model design and attribute configuration guidance. <https://developer.apple.com/documentation/technologyoverviews/structured-data-models>
[^vision-ocr]: Configuring `VNRecognizeTextRequest` for accuracy, language correction, and performance. <https://developer.apple.com/documentation/Vision/locating-and-displaying-recognized-text>
[^visionkit]: VisionKit overview and document camera guidance. <https://developer.apple.com/documentation/VisionKit>
[^nltagger]: Tokenization with `NLTagger` using `.tokenType` for word units. <https://developer.apple.com/documentation/coreml/finding-answers-to-questions-in-a-text-document>
[^hig-color]: Apple Human Interface Guidelines on color usage and accessibility pairing. <https://developer.apple.com/design/human-interface-guidelines/color>
