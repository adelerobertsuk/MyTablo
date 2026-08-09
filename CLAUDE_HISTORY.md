# ReadingTable / MyTablo — History Archive

Completed decisions, resolved bugs, feature build logs, and superseded/future-idea narratives, moved out of `CLAUDE.md` on 2026-08-09 to keep the main file lightweight (Native Engineer / token-diet protocol). Read only when explicitly reviewing past context — not loaded by default.

## Project rename & setup (completed 2026-08-08)
**Consumer-facing app name: MyTablo** (renamed from "Tablo"). GitHub repo, Xcode project file, and both target names are now `MyTablo` — only the bundle identifier is still `com.adeleroberts.Tablo`, deliberately, to avoid a duplicate app install mid-testing and re-doing the WeatherKit Apple Developer Portal step; revisit right before App Store submission.

- **GitHub repo** renamed by Adele via github.com → Settings. Now `github.com/adelerobertsuk/MyTablo` — old `ReadingTable` URL still redirects. Local `git remote origin` updated to match.
- **Xcode project renamed**: `ReadingTable.xcodeproj` → `MyTablo.xcodeproj`, both schemes, both target `name`/`productName` fields, via precise targeted edits to `project.pbxproj` (verified line-by-line via a Python script asserting an exact match count before writing). Widget extension's `CFBundleDisplayName` → "MyTablo Widgets".
- **Deliberately left unchanged**: both `PRODUCT_BUNDLE_IDENTIFIER`s, the physical `ReadingTable/`/`ReadingTableWidgets/` source folders (file-system-synchronized groups — `path` is load-bearing), both `.entitlements` filenames, `ReadingTableWidgets/Info.plist`'s path, and the widget's internal `kind: "ReadingTableWidgets"` string (renaming risks breaking already-placed home screen widgets, tracked by kind identifier).
- **Verified**: clean DerivedData + full `xcodebuild clean build` succeeded, `MyTablo.app` with `MyTabloWidgetsExtension.appex` correctly embedded. Confirmed via `PlistBuddy` both bundle identifiers byte-for-byte unchanged.

## Roadmap (logged 2026-08-07)
- [x] Default startup table: use `Kate-table-WhitePlaster` instead of `Kate-table-AntiqueWood`.
- [x] Z-order fix: newly added books/decorations always land on top.
- [x] Top-of-table white gap fix: `.scaleEffect(1.04, anchor: .bottom)` before `.clipped()` crops the baked-in fade on `Kate-table-*` surfaces (TabloView.swift, CoffeeTableViewIntegrated.swift).
- [x] Library: edit a book card in place (title, author, custom cover) via `EditBookView`. Fixes blank cards from failed ISBN lookups.
- [x] **Barcode scanner (VisionKit)** — `Views/BarcodeScannerView.swift`, wired into `AddBookView`. `DataScannerViewController` (EAN-13/EAN-8/UPC-E/Code128), `.isSupported`/`.isAvailable` fallback. Requires `NSCameraUsageDescription`. **Confirmed working on real device 2026-08-07.**
- Device note: Adele's iPhone previously had no data connection over cable (charge-only cable/blocked port) — **resolved 2026-08-08**, now connects cleanly.
- [x] **Camera scan cover capture — built 2026-08-08.** Upgraded from plain `UIImagePickerController` to VisionKit's `VNDocumentCameraViewController` (`Views/CameraCoverCapture.swift`) — auto edge detection, perspective correction, corner adjust/retake. Button relabelled "Scan Cover." Reuses `normalizedOrientation()` + JPEG pipeline and existing `NSCameraUsageDescription`.
  - **Three-way cover picker follow-up**: single "Add Cover" button opens a `Menu` — Scan Cover (`viewfinder`), Take Photo (`camera`), Choose from Library (`photo.on.rectangle`). Added `RawPhotoCaptureScreen` for plain camera; gallery upload via `.photosPicker(isPresented:...)`.
  - **Bug: Scan Cover saved black/inverted colors.** Root cause: `normalizedOrientation()` skipped its redraw pass when `imageOrientation == .up`; VisionKit's scanner always returns `.up` but in a non-standard color space. Fixed by always redrawing regardless of orientation.
  - **Investigated further — confirmed NOT a code bug.** Dark/glossy/metallic covers (e.g. "Human Design Unlocked") still came out black even in Apple's own Notes scanner — inherent to `VNDocumentCameraViewController`'s auto-exposure tuning for white paper. Confirmed working correctly on matte covers ("Outsmarting Reality"). Workaround: use Take Photo/Choose from Library for problem covers.
  - **Background removal (subject lift) — built.** `VNGenerateForegroundInstanceMaskRequest` via new `BackgroundRemovalReviewScreen` (checkerboard preview, "Remove Background"/"Try Again"/"Use Photo"). Cutouts save as PNG, plain photos as JPEG. Runs off main thread via `Task.detached`.
  - **Bug: Take Photo/Choose from Library stuck on blank white screen after capture.** Root cause: `CustomCoverPicker` had two independent boolean-driven `.fullScreenCover`s racing a transition. Fixed via `pendingReviewImage` + `presentReviewIfNeeded()` sequencing.
  - **Bug: silent failure picking a Photos-exported sticker PNG via Choose from Library.** `try?` on `loadTransferable` swallowed the error. Fixed with a proper `do/catch` + `loadError: String?` shown under the "Add Cover" menu.
  - **Confirmed — Take Photo freeze persisted after genuine rebuild, root-caused differently.** Two separate `.fullScreenCover`s handing off (camera → review) don't reliably sequence on real hardware even with `onDismiss`. Fixed by merging both into one continuous `.fullScreenCover` (`CameraCaptureFlowScreen`) with an internal `@State` content swap instead of a modal handoff.
  - **Fixed: "Kate's red journal" card taller than neighbors in Library grid.** `.aspectRatio` applied directly to a `ZStack` containing a large image let the image's layout negotiation skew the frame. Fixed by sizing a `Color.clear` first, then overlaying the image.
- [x] In-app ISBN search via OpenLibrary — confirmed working live.
- [x] **Crash: deleting a book placed on the Table crashed `Fatal error: This model instance was invalidated`.** Root cause: `ComposedBook.book` has no inverse relationship, so SwiftData couldn't auto-clear a table placement on delete. Fixed via `removeBookFromCompositions(_:)` in `LibraryViewModel.swift`, called before delete.
- [ ] Title search (type a title, pick from matches) — explicitly deferred by user 2026-08-07, wants it later. Distinct from ISBN lookup, needs a results-picker (title can match multiple editions).
- [x] **Snapshot & export** — `Views/TableSnapshotView.swift` (chrome-free `ImageRenderer` render) + Share button in `TabloView`'s control bar.
- [x] Watermark restyled to bottom-center "Made on Tablo" pill (legible on light/dark surfaces) + pre-filled share caption. Paid watermark-removal option still just an idea.
- [x] **Bug: Share sheet blank then crashed.** Replaced custom `ShareSheet`/`UIActivityViewController` wrapper entirely with native `ShareLink`. **Confirmed working on real device.**
- [x] **Bug: shared image missing decorations/stale.** Cached `shareImage` wasn't refreshed on return from Style view. Fixed via `.fullScreenCover(..., onDismiss: refreshShareImage)`.
- [x] **Regression: dragging books jittery after delete-button restructuring** — confirmed fixed ("it moves beautifully now"); gesture attachment point moved back after scale/rotate/position transforms.
- [x] **Sticker/decoration resize broken (books fine).** Root cause: `DecorationView.swift` had `.gesture(dragMagnifyRotateGesture)` and an uncomposed `.onTapGesture` stacked on the same view. Restructured to split `coverContent` (tap-select) from a sibling `deleteButton`, gesture on the outer transformed view — matching `TableBookView`'s working pattern.
- [x] **Bug: Share button greyed out, did nothing.** The `DispatchQueue.main.async` deferral around reading `renderer.uiImage` got dropped during the `ShareLink` rewrite — re-added.
- [x] **Real crash: `SIGKILL`, Energy Impact High, sharing to Messages.** Passing `SwiftUI.Image` directly as the `ShareLink` item is inefficient for Messages. Fixed by sharing PNG `Data` via `ShareableTableSnapshot: Transferable`.
- [x] **Bug: black line at bottom of shared snapshot.** `scaleEffect` anchor had drifted from `.bottom` to `.center`. Reverted.
- [x] "Tokyo & Beyond" duplicate-book question — resolved, was a phone glitch during testing, not a code bug.
- **Session paused 2026-08-08** (through commit `4f458ff`, `widget-feature`, clean tree). "None of Library/Style/Share respond" turned out to be an Xcode/LLDB slow-attach false alarm from repeated rebuild cycles — resolved after a clean settled launch, no code fix needed. All prior re-tests confirmed working on real device.
- [x] **Grid-snap + double-tap-to-straighten** for books — "Snap to Grid" toggle (40pt grid), double-tap resets rotation. Verified in Simulator.
- [ ] Quick-swap surface themes: gesture/menu to cycle table textures.
- [x] **Sticker packs**: "Coffee House" (21) and "Fall Desk" (16) tabs added alongside "Desk Plants." Not yet added: Desk Supplies, Pastels Washi Tape, Witchy Desk Supplies, Ultimate Crystal Collection (94), Fall Oracle Deck (33, tarot-style, may not fit). Source: `~/Documents/Curio Design Assets/Stickers/`.
- [ ] More Kate table textures: 7 unimported "-2" variants in `~/Documents/Curio Design Assets/Table Surfaces/Kate TableSkapes/` (antiquewood-2, concrete-2, linen-2, marble-2, steel-2 [new], whiteplaster-2, wood-2). Lower priority than stickers.
- [ ] Future idea: a "radio" decoration playing music via the phone when tapped — later became the Music/record-player decoration below.
- [~] **Home screen widget — "Current Read."** `ReadingTableWidgets` extension, small (2×2), most-recently-added book placeholder (no "currently reading" flag existed yet). Shared SwiftData store via App Group (`group.com.adeleroberts.ReadingTable`), one-time migration in `ReadingTableApp.swift`. `LibraryViewModel` calls `WidgetCenter.shared.reloadAllTimelines()` on changes.
  - Verified in Simulator (both targets build clean) and on real device (widget renders, App Group/store/extension plumbing works end to end).
  - **Follow-up: same "invalidated model" crash after rebuild** — the earlier fix only prevented *future* corruption, didn't repair an already-dangling `ComposedBook` on-disk. Fixed via `repairDanglingBookReferences()` in `CoffeeTableCompositionViewModel.loadCompositions()`, comparing `persistentModelID`s on every load.
- **Fixed — crooked cover art in widget.** `PhotosPicker` saves kept only the EXIF orientation tag, which WidgetKit doesn't honor reliably. Fixed via `normalizedOrientation()` baking orientation into pixels via `UIGraphicsImageRenderer`. Commit `7f58539`.
  - **Bug: watermarked/text-covered artwork in widget.** Not a widget bug — the *stored* cover data already contained a previously-exported Tablo snapshot (with watermark) that got saved back in as a custom cover. Fix path: replace the cover via `EditBookView`.
  - **Tooling notes (recurring across sessions)**: synthetic Simulator taps stopped registering — first at the home-screen level entirely, later narrowed to native SwiftUI `Button` controls specifically (plain `.onTapGesture` on `Color.clear` layers kept working). Treated as an environment/tooling limitation, not an app bug, across multiple sessions — retest on real device or fresh Simulator session when blocked.
  - **Git credentials**: `git push`/`fetch` from Claude's tool session initially failed with no GitHub credentials (`could not read Username`) — Adele pushed via GitHub Desktop as a workaround. **Update (later session): this no longer holds** — `git push origin widget-feature` succeeded directly (commit `039a37e`). Treat "Claude can't push" as no longer a safe assumption.
  - **Requested, not yet scoped at the time — favorite/"Currently Reading" flag.** Later built, see iPad test round below.
  - **Future idea: OCR auto-fill for Manual add form** via `VNRecognizeTextRequest` on the captured cover image — not scoped or started.
- [x] **Bug: book z-order stuck.** `.onTapGesture { selectedBook = nil; ... }` attached to a `Group` propagates to every child individually (`Group` is modifier-transparent), so every book tap also fired the competing deselect gesture. Fixed by moving the deselect gesture to its own dedicated background layer (same fix applied to `TabloView.swift`'s "tap to reveal control bar"). **Confirmed on real device.**
- [x] **Bug: can't delete a book from table (delete X visible but inert).** `.highPriorityGesture` on the whole card took priority over the nested delete `Button`. Fixed by making the delete button a sibling overlay outside the gesture-bearing view. Also replaced every `try? modelContext.save()` with a `save()` helper surfacing real errors via an alert. **Confirmed fixed on real device.**
- [x] iPad support exploration — confirmed working in Simulator (iPad Pro 13" M5): Table, Library grid, Add Book sheet, Stickers picker all render correctly, sheets stay centered. Cosmetic-only bug noted: "Library" label truncates to "Libr…" on both iPhone/iPad.
- [ ] Exploration: "nightstand" mode.
- [ ] Exploration: native clock display on the table (predates the Clock decoration below — separate "always visible, non-decoration" idea, still open).

## Release-readiness pass for App Store launch (logged 2026-08-08)
Working toward a back-to-school App Store launch. Full P0/P1/P2 audit done.

- [x] **Bundle identifier fixed** — was malformed/tripled, confirmed not registered anywhere, changed to `com.adeleroberts.Tablo` / `com.adeleroberts.Tablo.Widgets`.
- [x] **App Group migration data-loss risk fixed** — migration previously marked itself done (via `defer`) before confirming the file copy succeeded. Now only marks done on genuine success or nothing-to-migrate; failed copy retries next launch.
- [x] **Silent "Unknown Book" placeholder removed** — `BookMetadataProvider.swift` now throws `BookMetadataError.notFound`/`.lookupFailed`, surfaced via existing error UI.
  - **Bug: custom covers cropped/oversized in Library grid vs. Add/Edit preview.** Grid tile used a fixed 140pt height (mismatched aspect ratio) vs. the preview's 120×170. Fixed by matching the grid tile's aspect ratio to the preview. `TableBookView` left alone (already matched, and its frame is tied to stored absolute table positions).
  - **Bug: ISBN field retained previous book's value on reopening Add Book.** `addBookManually` never cleared `isbnInput`. Fixed by clearing on sheet dismiss regardless of outcome.
  - **Manual entry added** — real ISBN-not-found case (`9781068486005`, "Outsmarting Reality") prompted a segmented "By ISBN"/"Manual" picker in `AddBookView`; `addBookManually(title:author:coverImageData:)` generates a synthetic `"manual-<UUID>"` ISBN. Failed lookups also show an "Enter details manually instead" button.
- Outstanding, handed to GG (ChatGPT) for drafting: Apple privacy manifest (`PrivacyInfo.xcprivacy`), Privacy Policy + Support page copy, 8 unlabeled icon-only buttons + 4 undersized tap targets — apply once drafted.
- Undecided: keep iPad in v1.0 `TARGETED_DEVICE_FAMILY` given limited iPad testing time (share-sheet bug affected iPhone too, not iPad-specific).

## Future ideas — "app within an app" desk widgets (logged 2026-08-07, re-raised 2026-08-08)
Original brain-dump, explicitly deferred at the time: post-it notes, calendar (EventKit), map/globe (Core Location), weather (WeatherKit), Apple-Music-linked player, miniature stock-app decorations (alarm/world clock/timer/stopwatch), instant-camera decorations (Polaroid/Fuji/Kodak, both decorative and functional photo frames), user photo into a blank Polaroid frame (Kate had blank artwork ready).

**Re-raised 2026-08-08** after Adele asked Kate (a real end user) what she'd want next — mapped almost exactly onto the list above, plus a new "open journal page" idea (clarified below). Claude's priority assessment at the time:
- Easiest: Sticky notes (reuses `DecorationView.swift`, no new permissions).
- Next: Calendar (EventKit, permission prompt, no special entitlement).
- Then: decorative clock/world-clock (can't integrate with real Alarms app — no public API).
- Higher effort: Weather (WeatherKit) and Location (Core Location) — need Apple Developer entitlement setup.
- Most complex, save for last: real Apple Music playback (MusicKit) — subscription/entitlement dependency.

**Order confirmed by Adele: Sticky Notes → Calendar → (later, reprioritized) Weather bumped ahead of Clock/Location/Calculator/Music.**

### Sticky Notes — built and confirmed working on real device
Reused the `Decoration` model/gesture system: optional `noteText`/`noteColorName` fields (default nil) + `isStickyNote` flag on a sentinel `imageName`. `DecorationView.swift` renders a colored rounded-rect "paper" with overlaid text in one of 4 pastel colors (`StickyNoteColor`). `StickyNoteEditorView` sheet for add/edit; `CoffeeTableCompositionViewModel` got `addStickyNote`/`updateStickyNoteText`.
- **Fixed: pencil "Edit" opened a blank "New" sheet instead of pre-filled edit mode.** Replaced boolean state with `StickyNoteEditorContext: Identifiable` + `.sheet(item:)`.
- **Verified: double-tap-to-straighten on decorations already correctly wired**, no change needed.
- **Added, confirmed on real device: stronger shadow** (own `.compositingGroup()`, opacity 0.28–0.35, radius 6–9) so notes read as lifted off the table rather than flat.

### Calendar decoration — built and confirmed working on real device
Live, read-only, nothing stored on `Decoration` (fetched fresh each time). `Decoration.calendarImageName`/`isCalendar`. New `Services/CalendarService.swift` (`@MainActor`, `ObservableObject`, needs `import Combine`) wraps `EKEventStore`, `requestFullAccessToEvents()`, fetches/sorts/caps today's events at 3. `CalendarDecorationContent` — red weekday strip, day number, month, up to 3 events or a placeholder. Deliberately no in-decoration "Allow Access" button (past gesture-layering bugs starve nested tappables) — relies on the system prompt. Added `INFOPLIST_KEY_NSCalendarsFullAccessUsageDescription`.
- **Privacy caption extended**: `sharingPrivacyNotice` in `TabloView.swift` now checks photos and calendar independently, shown only when at least one is present. Sticky notes never trigger it (explicit instruction).
- **Build note**: needs explicit `import Combine` for any file using `@Published`/`ObservableObject`.
- **Bug fixed: main Table view didn't pick up a newly-added event though Style view did.** `.task` only runs once per view instance; Table view's decoration stays alive across backgrounding. Fixed via `.onChange(of: scenePhase)` refetch + `CalendarService` observing `EKEventStoreChanged`.
- **Confirmed: reads every calendar the device has access to** (`calendars: nil` in the predicate), not just one default. Multi-calendar refetch confirmed working on real device. Deliberately capped at 3 events by design, not a limitation ("I don't think people need... the whole calendar on there").

### Photo decorations — built, not yet tested on device at time of writing
Kate's Polaroid frame artwork (`Decoration-PolaroidFrame` imageset, genuinely transparent alpha-0 window, confirmed via pixel inspection) composited behind the user's photo. `Decoration.photoImageData: Data?` (default nil) + `isPhotoFrame` flag. Window bounding box computed via flood-fill from image center (~x 8–92%, y 8–79%). "Add Photo" button (`photo.on.rectangle.angled`) opens `.photosPicker`; pencil button replaces the photo. Routes through the same `normalizedOrientation()` JPEG pipeline as book covers. `addPhotoDecoration`/`updatePhotoDecorationImage` added to `CoffeeTableCompositionViewModel`.
- Share-time privacy caption keyed off `isPhotoFrame` specifically — sticky notes alone don't trigger it (confirmed correct, no change needed).
- Later/Kate-supplied variants not in v1: torn-edge print, tiny framed portrait, photo-booth strip, photo tucked into an open journal page. Guiding question for the whole section: "what would someone lovingly place on their real table?"

### "Open journal page" clarified
Kate's idea: freehand drawing via Apple Pencil/finger on journal-page artwork. **PencilKit** (`PKCanvasView`) natively supports both — genuinely feasible future scope, not started. Also flagged as relevant to iOS 27's rumored foldable-phone support. Related, also deferred: draw-on-sticky-notes idea (small `PKCanvasView` per note instead of/alongside the `TextEditor`).

### Big vision — "harness what the phone already does" / personal dashboard direction
Adele wants MyTablo to replace several separate home-screen widgets by being the one dashboard. Two flavors, same destination:
- **Kate's (journal/paper):** Polaroid photo-drag-in, blank writable paper — decorations personalized with own content.
- **Adele's (glanceable OS-level dashboard):** drag own photos onto blank Polaroid art; Steps widget (HealthKit, read-only); water tracker (HealthKit water-intake type exists but most tracking is 3rd-party, may need own in-app tracker); "currently listening" decoration deep-linking to the audiobook app (no API to auto-detect what's playing — would start as manual pick); location decoration; clock/time (shipped, see Utility-object section); favorite photos of loved ones; alarm decoration (fine if decorative-only, no real Alarms API). Adele is pre-emptively fine with all the implied permission prompts (HealthKit, Photos, Location, Calendar, etc.).
- **Camera-launcher decoration — not buildable as literally described, explained to Adele, not built.** Apple has no public URL scheme for the stock Camera app (unlike Settings/Mail/Maps). Realistic alternative: a decoration opening *this app's own* camera flow, styled like a camera object.
- [x] **Calculator decoration — built.** `Decoration.calculatorImageName`/`isCalculator`. Static icon card on table; "open" overlay button presents `CalculatorSheetView` (+/−/×/÷, %, ±, clear, chained ops). Pure SwiftUI, no permissions. `divide.square.fill` control-bar button.
- [x] **Location decoration — built.** Mirrors Weather's pattern: `Services/LocationService.swift` (`CLLocationManager` when-in-use + `CLGeocoder` reverse-geocode to city/region), `LocationDecorationContent`, `mappin.circle.fill` button. Reuses/broadens Weather's `NSLocationWhenInUseUsageDescription`. `CLGeocoder` deprecated in iOS 26 in favor of MapKit's `MKReverseGeocodingRequest` — left as-is, functionally fine, worth migrating later.
- [x] **Music decoration — rebuilt as a bundled-audio record player** (superseded an earlier deep-link-only version). Per Adele/Kate's request for "a little record player, like the MD vinyl."
  - **5 tracks from Pixabay Music** (royalty-free, no login needed via each track's own page), bundled at `ReadingTable/Resources/Music/record-track-1.mp3`–`5.mp3` (~21.6MB total): "Calm Peaceful Chill Hop" (FASSounds), "Lofi Study Session" (alex-morgan), "Lofi Study" (The_Mountain), "Lofi Study Rainy Night" (alex-morgan), "Study Lofi Music" (mirostar). Licensing/attribution detail: see `project_music_decoration_pixabay` memory.
  - New `Services/RecordPlayerService.swift` (`@MainActor`, `ObservableObject` singleton) wraps `AVAudioPlayer`; `RecordTrack` struct per file (title, artist, procedural accent color standing in for real album art); play/pause/skip; each track loops.
  - Table object: `RecordPlayerDecorationContent` — dark-plastic-and-brass turntable casing matching the clock/calculator material family, spinning vinyl (`VinylDiscView`), brass tonearm that lifts/drops with play state. Spin angle driven by a periodic `TimelineView` (not a started/stopped animation) so pause freezes cleanly with no snap-back.
  - `RecordPlayerSheetView`: full dark-themed player (`BigVinylDisc`, play/pause/skip, secondary "Open in Apple Music" link — later removed, see design reset below).
  - Interaction deliberately kept sheet-only (not table-mode-direct) to avoid touching the flagged-fragile gesture-layering code — reversed later per the design reset (see below).
  - Re-enabled the Music "add" button, previously hidden since the design review.

### Reading-continuity framing (via GG, not scoped or started)
GG's competitive-moat take: no single feature here is hard to copy alone — the moat is bundling a real book library + Kate's visual identity + easy arranging/sharing + personal content + live data into one coherent experience. For reading continuity specifically, three tiers: (1) extend Currently Reading with progress %/last-read date/favorite passages/goal — buildable now; (2) a book/audiobook decoration deep-linking to Kindle/Audible/Apple Books — buildable now; (3) automatic position sync — **not buildable**, no public API (Amazon doesn't expose Kindle/Audible position; Audible's Alexa route needs Amazon review with strict limits). Recommended near-term: manually-updated "67% read" badge, architected so real sync could slot in later.

## Future direction — Widgets: Tablescape Mode + Library Shelf Mode (logged 2026-08-07)
**Not started — architectural direction only, retained for a future dedicated widget effort.**

Two planned presentation modes: **Tablescape Mode** (responsive render of the saved composition, adapted to widget sizes) and **Library Shelf Mode** (compact book-spine view, better for small widgets). Library Shelf Mode requirements once built: generate spine art from stored cover colors/title/author (no separate spine photography); preserve per-spine individuality; support small/medium/large/XL widget families; small = a handful of spines, larger = more shelves/collection; possible collections (Currently Reading, Recently Added, Favourites, user-selected); tap opens Library; only WidgetKit-supported interactions/refresh; no tiny unreadable text; Lock Screen/StandBy get their own deliberately simplified designs, not a shrunk full bookshelf.

## Future idea — separate "vision board" app (logged 2026-08-07)
A second, similar app on the same pattern as ReadingTable/MyTablo but for a vision board. Kate has artwork ready. Not started, not scoped — would be a new Xcode project, not a MyTablo feature.
- Camera/barcode features need a physical device — Simulator has no real camera feed.
- 5 unused, unrelated `table-*.imageset` assets in Assets.xcassets (concrete/linen/marble/travertine/wood, no "Kate" prefix) — orphaned placeholders, safe to delete if cleaning up, left alone unless asked.

## iPad real-device test round (logged 2026-08-08)
- [x] **Bug: sharing from iPad rendered the book massive, black bar returned.** `TableSnapshotView`'s `size` defaulted to a hardcoded iPhone canvas (402×874); `refreshShareImage()` never overrode it. Fixed by capturing the live table's `GeometryReader` size into `tableSize` and passing it to `TableSnapshotView(composition:size:)` on every refresh.
  - **Unresolved follow-up**: a later screenshot showed large black bars above *and* below content (not just a thin line) — Adele didn't confirm which app/screen it was in, so it's unclear whether it's baked into the PNG or is viewer chrome. Not investigated further.
- [x] **Bug: iPad share sheet showed a redundant "MyTablo" title line.** `SharePreview("MyTablo", ...)` duplicated the `message:` caption. Fixed by passing an empty title.
- [x] **Bug: background-removal cutouts (Take Photo/Choose from Library) came out skewed.** Unlike Scan Cover (VisionKit corrects perspective), these paths never straightened the photo. Fixed via `straightenedIfPossible(_:)` (`VNDetectRectanglesRequest` + Core Image `perspectiveCorrection`), run automatically before Remove Background/Use Photo can act; silently falls back to the original if no confident rectangle found.
- [x] **Feature: "Currently Reading" flag** so the widget shows a chosen book, not just most-recent. `isCurrentlyReading: Bool = false` on `Book` (defaults, existing records stay loadable). `setCurrentlyReading(_:isCurrentlyReading:)` clears any other flagged book first (one slot). Bookmark-icon toggle in `BookTileView`. Widget's `TimelineProvider` prefers the flagged book, falls back to most-recent.
- Reported, not yet investigated: home screen widget on iPad shows up but loads no books at all (distinct from the wrong-book placeholder behavior).
- Discussed, deferred: book categories/tags with possible smart sorting — larger feature, needs tagging UI + Library filtering.
- Discussed: Apple Watch face "mirror" decoration — not possible, Apple exposes no API to read/mirror real watch face content. Realistic alternatives: a decorative clock-face object, or a proper watchOS companion app.
- [ ] **Reported, not root-caused — iPad portrait: "not quite the right canvas size."** No specifics given (stretched/squished/cut off/wrong aspect). Background surface already fills correctly via `GeometryReader` + `.scaledToFill()` + `.clipped()`; book/decoration positions are stored as absolute coordinates tied to placement-time screen size (same root cause as the iPad share-sizing bug), so cross-device/orientation placement could feel off. Needs a specific follow-up description/screenshot from Adele before fixing with confidence.

## Requested 2026-08-08 (from iPad session) — backlog
- [ ] More sticker packs — Adele mentioned Kate has a "paper" pack plus other bits; doesn't obviously match the already-known not-yet-added list (Desk Supplies, Pastels Washi Tape, Witchy Desk Supplies, Ultimate Crystal Collection, Fall Oracle Deck) — check `~/Documents/Curio Design Assets/Stickers/` for an unnamed pack.
- [x] "Favourite"/widget-loading feature — same as the Currently Reading flag above, just needed the iPad retest (still pending).
- [ ] Other widget sizes (medium/large/XL) — ties into the Tablescape/Library Shelf Mode direction above, the natural place to design what larger sizes show.

### Weather decoration — build history (superseded by the design reset below)
Priority bumped ahead of Clock/Location by Adele ("such a cool unique feature").
- Built mirroring the Calendar pattern: `Decoration.weatherImageName`/`isWeather`, `Services/WeatherService.swift` (`CLLocationManager` + WeatherKit's `WeatherService.shared.weather(for:)`, refetch on `scenePhase` active), `WeatherDecorationContent`, `cloud.sun.fill` control-bar button. Added `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription` + `com.apple.developer.weatherkit` entitlement.
- **Blocker resolved**: WeatherKit needs a paid Apple Developer Program membership + the WeatherKit capability added via Xcode's Signing & Capabilities. Adele confirmed her account is paid and the capability shows added; rebuild confirmed `com.apple.developer.weatherkit = 1` embedded in compiled entitlements.
- Deliberately excluded from `sharingPrivacyNotice` — a temperature reading isn't as identifying as a calendar title or personal photo.
- **Diagnostic tool: built a Clock decoration** specifically because it needs zero permissions/entitlements, to isolate whether "not loading" was WeatherKit-specific or a broader rendering/tooling issue. (This diagnostic became the design-review exemplar — see below.)
- **Root cause of "not loading" found**: `didFailWithError` was a silent no-op, and the service's initial/blank state was indistinguishable from its failure state — any fetch failure left it stuck looking like "still loading" forever. Fixed with real `isLoading`/`fetchFailed` published state.
- **Root cause of a second "stuck on loading" case (iPad)**: `CLLocationManager.requestLocation()` has no built-in timeout; Wi-Fi-only iPads without GPS can simply never get a fix, so neither delegate callback ever fires. Fixed via `startTimeoutWatch()` — after 15s with no result, surfaces "Weather unavailable" instead of hanging indefinitely. Does not fix location/WeatherKit itself, just guarantees the object never looks silently stuck.

## Utility-object design reset — full handover 2026-08-08 (evening)
**Verdict: Calendar is the only new utility object whose visual direction currently passes.** Record player, Clock, Weather, and Calculator are prototypes, not approved designs — flat/childish/clip-art-like next to the app's photorealistic books/flowers/Polaroids. Would rather temporarily remove an object than ship below MyTablo's quality bar. No further visual implementation happened that evening, and none should happen until direction is re-approved with Adele, Kate, and Gigi.

**Preserve, don't discard**: all four objects' underlying functionality (record playback, live clock, calculator logic, weather fetch+timeout) stays as-is in code — this is an art-direction reset, not a feature rollback.

### What was actually built as exemplars before the reset (now paused, functionality retained)
- **Clock — approved as the exemplar** ("Love the clocks. They're absolutely fabulous."): `DigitalClockFace` (dark plastic casing, amber LED digits, small feet) and `TravelClockFace` (brass bezel, angular-gradient sheen, cream dial, carrying ring). Fixed the truncated-minutes bug (`18:3` → `18:03`) via `.dateTime.hour().minute(.twoDigits)`.
- **Weather — redesigned as a brass desk barometer** reusing `TravelClockFace`'s exact material palette, three intentional dial-integrated states (location-denied / "Reading the sky…" loading / "Weather unavailable"). Visual design confirmed by Adele and Kate on iPad (kept matching the clock's brass rather than going silver).
- Both **not yet done at reset time**: the design doc's rule that core function should work from normal Table mode, not just Style mode — deliberately deferred each time to avoid the flagged-fragile gesture-layering code (Group-modifier propagation, `highPriorityGesture` blocking nested buttons).

### Record player specifics (reset brief)
- The MD Vinyl player referenced earlier was a **quality reference only** — do not copy its proprietary assets or ship a simplified cartoon version.
- Target: premium, photorealistic/editorial-quality transparent-background tabletop object, fully draggable/rotatable/scalable, never fixed in place, with obvious functional controls. Likely shape: a high-quality transparent visual asset with SwiftUI controls layered discreetly on top. Kate may supply artwork, or Gigi may generate/prepare it.
- Remove every Apple Music reference and the "Open in Apple Music" link/branding — the 5 tracks are royalty-free Pixabay audio, must be labeled accurately with correct artist/attribution per licence. Playback (play/pause/skip) must work from normal Table mode, not just the Style-mode sheet (reverses the earlier "kept small" decision). Show a clear playing-state indicator.

### Clock / Weather / Calculator specifics (reset brief)
Pause current artwork — functional logic can stay. Standing design bar for every future utility object:
- Must look deliberately placed on a beautiful coffee table — no generic cards, white squares, SF Symbol tiles, or cartoon drawings.
- Must share the depth/lighting/material quality/restraint of existing books and decorations.
- Avoid cramming in too much info; stay readable at multiple sizes.
- Core function must work from normal Table mode, not just Style mode (Style mode is for adding/arranging only) — same gesture-layering caveat applies.
- Empty/unavailable states must still look intentional and beautiful, not broken.
- Preserve drag/scale/rotate/layer/delete; meet accessibility requirements without hurting the aesthetic; never falsely claim integration with another service.

### Next session's deliverables (before any more implementation) — still the standing plan
1. Short audit of current implementation.
2. What functionality is retainable independent of artwork.
3. 2–3 visual-object concepts per utility (record player, clock, weather, calculator).
4. Recommendation per object: supplied artwork, generated artwork, or native SwiftUI drawing.
5. No further implementation until this direction is approved — start with proposing/discussing, not coding.

**MyTablo acceptance test for any new/reworked object:** doesn't lower the table's visual quality; looks credible beside a real photographed book or flower; purpose obvious without explanation; core function works outside Style mode; attractive at multiple sizes; never falsely claims integration with another service; Adele and Kate would willingly leave it visible on their own tables all day.

## White Rabbits — full brief history (Team Polaris, separate app, targeting ~2026-09-01)
See `CLAUDE.md` for the current, condensed active-constraint summary. Full detail below.

A **new, separate iOS app**, not a MyTablo feature. Do not begin coding until scoped with Adele — start by inspecting any existing Gemini prototype/files (location not yet known — ask Adele), then propose architecture and an MVP plan, preserving useful prototype work without letting it dictate the final design.

**Concept**: turns the first-of-the-month "White Rabbits" good-luck tradition into a monthly ritual app — gentle reminder to say "White Rabbits" on the 1st, confirm you remembered, unlock that month's limited-edition collectible bunny, start a fresh monthly page. Tone: simple, sleek, magical, calm, collectible, grown-up — luxury storybook/editorial stationery, explicitly not a cartoon habit-tracker. Never implies the app guarantees real luck.

**September MVP scope**: reminder evening-before/morning-of the 1st; first-of-the-month ritual screen; "I said White Rabbits" confirmation; one limited-edition bunny unlocked per month; a monthly intention (user-entered); one vision-board image per month; one simple monthly habit with an understated daily tracker; journal/archive of previous months + collected bunnies. Must handle months/time zones/notification scheduling/date changes reliably.

**Design/privacy constraints**: local-first where practical; no account required for MVP; optional iCloud sync is a later idea; notification permission optional and clearly explained; accessible text/controls/contrast/reduced-motion; no dashboards, streaks, stats, or social pressure; Kate's approved bunny artwork leads the visual identity; future seasonal bunny packs may support monetization later, not at MVP's expense.

**Next session's deliverables (research/planning only, no code yet)**: one-page product definition; September MVP vs. later roadmap; complete user journey; proposed data model; notification + first-of-month logic approach; visual direction + screen list; open questions for Adele/Kate; realistic plan for a polished September release.

**GG's "master prompt" spec (2026-08-09)** — sent to Adele for a separate thread/tool, not built here, introduces divergences from the brief above still needing resolution:
- Framed as a mobile-first **web app**, where the original brief says a native **iOS** app — unclear if deliberate (prototype/marketing site on web, native app later) or GG drafting for a different tool. Needs Adele to clarify before any build.
- Core mechanic differs: GG centers a **twelve-month ritual ring** (progress ring, 1/12–12/12 segments, streak count) with no bunny-collecting mechanic at all (bunny only as brand mark). Not obviously reconcilable with the original bunny-per-month centerpiece — ask Adele which is the real MVP mechanic.
- New surface area not in the original brief: full-width "Wake-Up Track" card (Apple Music selection triggering a 1st-of-month alarm — GG's own spec flags a browser can't do this natively, so it'd need to be an iOS/companion feature even in a web build), "Soft Guidance" reflection card informed by Apple Health rest data, grid/list journal views (strict reverse-chronological), detailed visual direction (pale lavender-grey/warm off-white, charcoal type, frosted-glass rabbit silhouette icon, no cartoon bunnies), full tone-of-voice copy bank, App Store positioning copy.
- Still true, not superseded: no coding starts until scoped with Adele; check for an existing Gemini prototype before assuming a blank slate; separate app/repo from MyTablo.

**Audience/tone correction (2026-08-09)**: Adele overrode GG's framing — "yes defo gen z and shareable. GG got it wrong." GG's "luxury storybook, grown-up, not shareable/social" framing is wrong and superseded. Correct target: **Gen Z, built to be shared on TikTok etc.** — sharing/collectibility is first-class, not an afterthought.
- **Icon direction (working, not yet finalized)**: "look cool and like Apple could have made it themselves," OVO (Drake) reference point. Claude's recommendation: bold flat single-color silhouette (no gloss/chrome, no thin line-art, no circle frame) on deep charcoal/black — iconic and readable at small sizes, close in spirit to OVO's owl mark.
- **Practical implication**: likely favors the original bunny-per-month mechanic (collectible culture is inherently Gen-Z/TikTok-native) over GG's ritual-ring/streak mechanic, and pushes visual tone bolder/graphic rather than soft pastel editorial. Not yet finalized — flag explicitly before locking the mechanic or full visual system.

**Reference app confirmed 2026-08-09 — "Erly: Wake Up Early"** (App Store, Glacier Labs LLC), cited by Adele as visual inspiration:
- **Icon**: flat black rounded-square, single bold white glyph (sunrise shape) — no gradient/gloss/photographic elements. Concrete "Apple could have made it" reference, alongside the OVO note.
- **UI pattern**: white cards, bold black sans-serif headlines, a simple week-strip streak tracker (S M T W T F S checkmarks) rather than GG's ritual ring, and a "Choose a Mission"-style full-screen unlock moment — screens designed to double as shareable/TikTok screenshots.
- **Tone — explicitly NOT to copy** (Adele: "totally agree"): Erly's copy is hardcore-accountability ("No excuses," "No cheating," "Prove to yourself you're ready to own the day"). White Rabbits' gentle, never-shame-the-user ethos stays — Gen-Z/shareable is a visual/mechanic axis, not permission for drill-sergeant copy. **Confirmed target voice: gentler-but-still-punchy TikTok-native — "Duolingo's owl energy, cheeky not harsh," not Erly's tough-love framing.**
