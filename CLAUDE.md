# ReadingTable (MyTablo)

iOS app (SwiftUI + SwiftData) that lets you build a virtual coffee table styled with your books. **Consumer-facing name: MyTablo.** GitHub repo, Xcode project, and both targets are `MyTablo`; bundle ID stays `com.adeleroberts.Tablo` deliberately until right before App Store submission (avoids re-doing the WeatherKit entitlement/duplicate-install dance). Use "MyTablo" in any new user-facing text.

Full historical logs, resolved bugs, and superseded feature write-ups live in [`CLAUDE_HISTORY.md`](CLAUDE_HISTORY.md) — not loaded by default, read only when explicitly reviewing past context.

## Working with Adele
- Adele is a **beginner** — explain concepts plainly, avoid unexplained jargon, keep answers focused.
- Token-efficient by default: read only what's needed, terse logs, diffs not full-file rewrites, no raw build spam. See memory `feedback_token_diet_protocol` / `feedback_native_engineer_role`.

## Team Polaris multi-AI workflow (active since 2026-08-09)
- **Claude Code's role = Native Engineer only**: translate already-approved designs (built in ChatGPT Sites) into SwiftUI/Xcode, implement Apple integrations (Music, Calendar, Photos, notifications, widgets, iCloud).
- **Logic separation**: Gemini Pro owns core/backend logic and data-flow design. Don't architect or debug large data flows from scratch — expect a pre-vetted spec to build from; if a task looks like backend/architecture work, flag it as Gemini's territory and ask for the spec.
- **Textual diffs only**: precise line-specific edits on existing files, never a full-file rewrite except for genuinely new files.

## Architecture
- **Pattern:** MVVM. Views observe `ObservableObject` view models. SwiftData for persistence.
- **Concurrency:** prefer async/await. Avoid Combine (view models still import it but don't rely on it — any file using `@Published`/`ObservableObject` needs an explicit `import Combine`).
- `ReadingTableApp.swift` is the entry point — builds the `TabView` and injects view models. (`ContentView.swift` is unused default template.)

### Files
- `Models/Book.swift` — SwiftData `@Model`s: `Book`, `CoffeeTableComposition`, `ComposedBook`.
- `Models/Decoration.swift` — decoration/utility-object model (stickers, sticky notes, calendar, weather, clock, calculator, photo frames, record player).
- `ViewModels/LibraryViewModel.swift` — add/delete/load books via ISBN or manually.
- `ViewModels/CoffeeTableCompositionViewModel.swift` — manage table arrangements (add/move/remove/z-order books & decorations).
- `Services/BookMetadataProvider.swift` — protocol + `OpenLibraryMetadataService` (live) + `MockBookMetadataService` (test data).
- `Services/CalendarService.swift`, `WeatherService.swift`, `LocationService.swift`, `RecordPlayerService.swift` — live-fetched utility-object data sources.
- `Views/LibraryView.swift` — Library tab UI.
- `Views/CoffeeTableViewIntegrated.swift` / `TabloView.swift` — Table tab UI (drag/scale/rotate books & decorations, pick table surface, share).
- `Views/DecorationView.swift` — all utility-object/decoration rendering.
- `Views/Widgets/SmallWidgetView.swift` — shared small home screen widget layout (app + `ReadingTableWidgets` extension).
- `ReadingTableWidgets/` — widget extension target; `ReadingTableWidgets.swift` has the `TimelineProvider` reading the shared App Group SwiftData store.

## Conventions
- PascalCase types, camelCase members; 4-space indent; no force-unwrapping.
- Use `DocumentationSearch` (xcode-tools MCP) for unfamiliar/new Apple APIs.
- Build with `BuildProject` (xcode-tools MCP), not command-line xcodebuild.
- Any change to a SwiftData `@Model` must keep existing local records loadable — new fields get defaults, never required.
- Gesture layering is a recurring regression source: don't stack an independent `.onTapGesture`/`.highPriorityGesture` alongside a nested `Button` or another gesture on the same view — split select/tap and drag/pinch/rotate onto sibling views instead (see `TableBookView`/`DecorationView` for the working pattern).

## Active constraints — read before touching Clock/Weather/Calculator/Music
**Utility-object visual design reset (2026-08-08):** Record player, Clock, Weather, and Calculator are prototypes only — rejected by Adele/Kate/Gigi as flat/childish next to the app's photorealistic books/flowers/Polaroids. **Only Calendar's visual direction currently passes.** Underlying functionality (playback, live clock, calculator logic, weather fetch+timeout) stays as-is — this is an art-direction reset, not a feature rollback. **No further visual implementation until direction is re-approved** by Adele, Kate, and Gigi — full acceptance-test bar, per-object briefs, and required next-session deliverables (audit → retainable functionality → 2–3 concepts per object → artwork recommendation) are in `CLAUDE_HISTORY.md` under "Utility-object design reset."
- **New brief for the redesign (2026-08-09):** Clock, Weather, and Music player should read as Gen Z / TikTok-shareable / status-symbol — sleek enough to photograph well, not just "not childish." Adele is taking a written concept brief to Gemini (deviates from the usual ChatGPT Sites design step — flagged, not yet reconciled) for 2–3 concepts per object before anything gets implemented here.
- **Direction candidate flagged by Adele (2026-08-09):** "liquid glass" material treatment for Clock/Weather/Music — either an iOS-style frosted-glass look, or built from actual iOS system icon/widget language, to sidestep the "childish toy" problem. Reference sent: notbor.ing/product/camera (their aesthetic is actually tactile/material-grounded with warm earth tones, not glass — the useful takeaway is craftsmanship-over-trend, not the translucency itself). Fold into the Gemini brief above; **no implementation until a concept is approved.**

## White Rabbits (separate app, Team Polaris, ~2026-09-01 target)
Not a MyTablo feature — do not code here. Confirmed direction: **Gen Z, built to be shared (TikTok etc.)** — collectible-bunny-per-month mechanic likely wins over GG's ritual-ring idea; OVO/"Erly: Wake Up Early" are the visual references; tone is gentle-but-punchy, never drill-sergeant. **Open question: web app vs. native iOS** — GG's latest spec says web, the original brief says iOS; ask Adele before building anything. Full brief in `CLAUDE_HISTORY.md`.

## Next steps (active backlog)
- Weather decoration: timeout/fetch bug fixed, needs a real-device retest.
- iPad canvas positioning — **root-caused and fixed (2026-08-09):** every new book/decoration was placed at a hardcoded absolute point `(150, 200)` (`CoffeeTableCompositionViewModel.swift`), sized for an iPhone canvas — on iPad's much bigger table it landed disproportionately small/cornered. Now placed at the actual canvas center (with slight jitter so repeated adds don't stack) via `StyleView`'s tracked `canvasSize`. Verified in iPad Simulator; needs a real-device confirm.
- Home screen widget — **verified working in iPad Simulator (2026-08-09)**, correctly showed a just-added test book by title/cover. The "loads no books" report may have been specific to real-device App Group/store-migration conditions (see `migrateExistingStoreIfNeeded` in `ReadingTableApp.swift`) — needs a real-device retest before closing out.
- ~~More sticker packs~~ — done (2026-08-09): added "Papers" and "Retro Paper" packs (23 stickers) to `StickerPack` in `DecorationView.swift`, verified in iPad Simulator.
- Real-device bugs found on Kate's iPhone (2026-08-09), fixed same day — **needs a real-device confirm**: control bar "Library"/"Style"/"Share" labels wrapped to two lines at larger Dynamic Type sizes (added `.lineLimit(1)`/`.minimumScaleFactor` in `TabloView.swift`); Papers/Retro Paper stickers rendered too small at the standard 70pt sticker frame — they're paper-scrap textures meant to read as a backing sheet, not an icon, so they now get a 130pt frame (`DecorationView.swift`).
- Apply once received from GG: Apple privacy manifest, Privacy Policy/Support copy, accessibility-label/tap-target fixes.
- Decide iPad's place in v1.0 `TARGETED_DEVICE_FAMILY`.
- White Rabbits: clarify web-vs-iOS with Adele, then inspect the existing Gemini prototype before scoping the MVP.
