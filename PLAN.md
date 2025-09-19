# PungentRoots v0.1 Implementation Plan

## 1. Product Goals
- Deliver a trustworthy on-device tool that flags pungent-root ingredients (garlic, onion, shallot, leek, chive, scallion) in photos or pasted text within the target performance budgets.
- Provide transparent explanations, risk scoring, and instant results while keeping scans ephemeral to preserve privacy.
- Lay foundations for extensibility (additional languages, custom rules, share extensions) without compromising the MVP timeline.

## 2. Guiding Principles & Apple Best Practices
- Keep all processing on-device and isolate state using SwiftUI environment injection so views stay declarative and testable.[^swiftui-state]
- Use SwiftData models as the single source of truth with explicit indexing and value preservation rules to avoid data loss when records evolve.[^swiftdata-model]
- Respect Apple’s Human Interface Guidelines by pairing color with clear iconography and typography, delivering accessible feedback across light/dark modes.[^hig-color]
- Prepare Vision and VisionKit requests up front, tune them for accuracy versus speed, and scope work to regions of interest to stay within latency targets.[^vision-ocr][^visionkit]
- Tokenize text with NaturalLanguage to reduce custom parsing logic and improve resilience to edge cases like Unicode punctuation.[^nltagger]

## 3. MVP Scope Check
- **Input:** Capture via VisionKit document camera (preferred) with quick relaunch; focus the app on scanning as the single entry point.
- **Detection:** Normalize, tokenize, run rule engine (exact/synonym/pattern/fuzzy), produce risk score, verdict, and rationale.
- **Output:** Highlighted text view, explanation list, verdict chip, and quick rescanning guidance (no persistent history).
- **Persistence:** Keep analysis ephemeral; explore opt-in storage later if user demand returns.

## 4. Architecture Overview
1. **Input Layer**
   - Route camera scans through a lightweight coordinator that owns `VNDocumentCameraViewController` lifecycle, converts pages to `CGImage`, and funnels them to OCR tasks.
   - Launch the camera directly from the home surface and expose a single CTA to rescan quickly.
2. **OCR & Normalization Service**
   - `TextAcquisitionService` orchestrates OCR tasks, returns normalized text with source metadata, and strips hyphen breaks, bullet characters, and problematic whitespace.
3. **Detection Engine**
   - Stateless service that consumes normalized text plus bundled dictionary JSON, emits matches with ranges and rationale, and scores risk per the weighting table.
4. **Presentation Layer**
   - SwiftUI navigation stack with a single Scan-first view, inline results card, and guidance messaging. Users expand the scanned transcript on demand via a disclosure control. Derived view state stays immutable and driven by services.

## 5. Text Capture and OCR
- Configure a reusable `VNRecognizeTextRequest` at startup, specifying `.accurate` recognition for document scans and enabling language correction to improve ingredient accuracy, with the option to fall back to `.fast` for degraded images.[^vision-ocr]
- Populate `recognitionLanguages` with `Locale.Language("en-US")` initially and expose a setting stub for future locales; rely on `supportedRecognitionLanguages` to validate availability.[^vision-ocr]
- Limit processing to the detected ingredient block (VisionKit’s pre-cropped output) or apply a lightweight rectangle detection before OCR to cut noise.
- Run OCR on a background task; return results via `MainActor` isolation to satisfy Vision threading requirements and update UI state safely.

## 6. Text Normalization & Tokenization
- Normalize using Unicode NFKC, lowercase, collapse whitespace, rejoin hyphenated breaks, and strip punctuation that splits tokens unexpectedly.
- Tokenize using `NLTagger(tagSchemes: [.tokenType])` with `.word` units and `.omitWhitespace` so the detection engine operates on consistent tokens regardless of input formatting.[^nltagger]
- Maintain UTF-16 ranges for matches to stay compatible with SwiftUI attributed strings.

## 7. Detection Engine
- Load the bundled dictionary JSON into a cached `DetectDictionary` struct at launch; watch for decode failures and surface a non-blocking alert path.
- Exact & synonym passes use regex with word boundaries; patterns handle suffixes like powder/salt/extract; ambiguous list triggers caution-tier matches; fuzzy pass applies Levenshtein distance thresholds for short vs. long tokens.
- Filter known false positives—`calcium`, `oil` variants, and generic "natural" flavoring references—before applying fuzzy heuristics, and keep thresholds tunable per locale.
- Accumulate scores by severity, cap ambiguous contributions, and keep verdict computation internal; the UI now surfaces just the matches so users can decide.
- Structure the engine for eventual replacements (e.g., Aho–Corasick) without changing the public API.

## 8. Data Handling
- Keep scans ephemeral; detection results live in-memory per capture with no disk persistence.
- Retain `Match` and `Verdict` value types for highlight rendering and analytics snapshots when users share feedback.
- Leave SwiftData hooks dormant behind feature flags so opt-in history can return without re-architecting core services.
- Tag each analysis with the bundled dictionary version via `AppEnvironment` for troubleshooting.

## 9. SwiftUI Experience
- Center the UX on a single Scan surface with a primary CTA, inline results card, and guidance card for quick rescans.
- Drive state entirely through SwiftUI `@State` and environment services, keeping the surface previewable and side-effect free.
- Annotate highlights using attributed strings so VoiceOver exposes match context via `accessibilityAttributedLabel` and not color alone.[^hig-color]
- Gate the full scanned transcript behind a "Show full scanned text" toggle so the match list remains the focus; highlight colors default to red for confirmed matches and yellow for possibles.

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
- Present camera permission copy emphasizing on-device processing and zero network use.
- Gracefully degrade: if OCR fails, surface inline guidance and relaunch actions so users can rescan quickly.
- Keep scans transient by default; if future releases add opt-in storage, pair it with clear privacy copy and easy deletion.

## 13. Delivery Timeline (10 Working Days + Buffer)
1. **Day 1–2:** Simplify navigation to the Scan-first surface, remove history/text entry, and update supporting copy.
2. **Day 3–4:** Harden the VisionKit capture + OCR pipeline and hook live detection results into the refreshed UI.
3. **Day 5:** Polish detection results card, inline guidance, and baseline theming for light/dark modes.
4. **Day 6:** Fuzzy matching refinements plus haptics and accessibility checks (Dynamic Type, VoiceOver).
5. **Day 7:** Error state messaging, camera permission flows, and logging instrumentation for scan attempts.
6. **Day 8–9:** Unit + integration tests, sample image fixtures, automation hooks (CI script skeleton).
7. **Day 10:** Polish, documentation updates, TestFlight packaging, and release checklist prep.
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
