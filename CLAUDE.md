# ReadingTable

iOS app (SwiftUI + SwiftData) that lets you build a virtual coffee table styled with your books.

## Working with Adele
- Adele is a **beginner** — explain concepts plainly, avoid unexplained jargon, and keep answers focused.
- Be token-efficient: read only what's needed, keep explanations tight.

## Architecture
- **Pattern:** MVVM. Views observe `ObservableObject` view models. SwiftData for persistence.
- **Concurrency:** prefer async/await. Avoid Combine (view models still import it but don't rely on it).
- `ReadingTableApp.swift` is the entry point — builds the `TabView` and injects view models. (`ContentView.swift` is unused default template.)

### Files
- `Models/Book.swift` — SwiftData `@Model`s: `Book`, `CoffeeTableComposition`, `ComposedBook`.
- `ViewModels/LibraryViewModel.swift` — add/delete/load books via ISBN.
- `ViewModels/CoffeeTableCompositionViewModel.swift` — manage table arrangements (add/move/remove/z-order books).
- `Services/BookMetadataProvider.swift` — protocol + `OpenLibraryMetadataService` (live) + `MockBookMetadataService` (test data).
- `Views/LibraryView.swift` — Library tab UI.
- `Views/CoffeeTableViewIntegrated.swift` — Table tab UI (drag/scale/rotate books, pick table surface).
- `Views/Widgets/SmallWidgetView.swift` — SwiftUI layout for the small home screen widget, shared into both the app and `ReadingTableWidgets` extension targets.
- `ReadingTableWidgets/` — the widget extension target (separate from the main app target). `ReadingTableWidgets.swift` has the `TimelineProvider` that reads the shared App Group SwiftData store.

## Features
- **Library tab:** enter ISBN → fetch title/author/cover from OpenLibrary → save. Grid of covers, delete via swipe or button.
- **Table tab:** choose a table surface image, add books from library, drag/rotate/scale them; autosaves on every change. Optional "Snap to Grid" toggle rounds drag positions to a 40pt grid; double-tap a book to reset its rotation to 0.

## Conventions
- PascalCase types, camelCase members; 4-space indent; no force-unwrapping.
- Use `DocumentationSearch` (xcode-tools MCP) for unfamiliar/new Apple APIs (Liquid Glass, FoundationModels, latest SwiftUI).
- Build with `BuildProject` (xcode-tools MCP), not command-line xcodebuild.
- Any change to a SwiftData `@Model` (adding/removing/renaming properties) must keep existing local records loadable — add new fields with defaults rather than making them required, so the persistent store doesn't crash on devices with existing data.

## Roadmap (logged 2026-08-07)
- [x] Default startup table: use `Kate-table-WhitePlaster` instead of `Kate-table-AntiqueWood`.
- [x] Z-order fix: newly added books/decorations should always land on top, not underneath existing items.
- [x] Top-of-table white gap fix: the six `Kate-table-*` surface photos have a soft transparent fade baked into their top ~19px; rendering now applies `.scaleEffect(1.04, anchor: .bottom)` before `.clipped()` to crop it out (TabloView.swift, CoffeeTableViewIntegrated.swift).
- [x] Library: allow editing a book card in place (title, author, custom cover) — tap any cover in the Library grid to open `EditBookView`. Fixes blank cards from failed ISBN lookups.
- [x] **Barcode scanner (VisionKit)** — `Views/BarcodeScannerView.swift`, wired into `AddBookView` via a "Scan Barcode" button that fills the ISBN field. Uses `DataScannerViewController` (EAN-13/EAN-8/UPC-E/Code128), checked with `.isSupported`/`.isAvailable` and shows a graceful fallback message when unavailable (confirmed working in Simulator, which has no camera). Requires `NSCameraUsageDescription` (added to project.pbxproj build settings). **Confirmed working on a real device 2026-08-07** — tested live on Kate's iPhone (paired over local network), scanned a real book barcode successfully.
- Device note: Adele's own iPhone ("Adele's iPhone" in `xcrun devicectl list devices`) would not establish a data connection over cable during testing — charged fine but Xcode/devicectl never saw it (`tunnelState: unavailable`, no fresh `lastConnectionDate`), while `system_profiler SPUSBDataType` showed no iPhone on USB at all. Likely a charge-only cable or a data-blocking hub/port. Kate's phone ("iPhone" in the device list) was already paired over Wi-Fi and used instead. Worth revisiting with a different cable/port next time Adele's own device needs testing.
- [ ] Camera scan: photograph a physical book's front cover to use as custom cover artwork. Also needs a physical device. **Raised again 2026-08-07** — user has "lots of books in the house that return blank artwork" from ISBN lookup, wants this as the fix instead of manually searching the internet for cover art. Growing priority.
- [x] In-app ISBN search — already implemented via OpenLibrary, confirmed working live (tested with a real ISBN, returned correct title/author/cover).
- [ ] Title search (type a book title instead of ISBN and get matching results to pick from) — explicitly deferred by user 2026-08-07 ("we'll leave that for now"), wants it added at a later date. Not yet built — distinct from ISBN lookup, needs a results-picker UI since a title can match multiple editions.
- [x] **Snapshot & export** — `Views/TableSnapshotView.swift` (clean, chrome-free render of the composition via `ImageRenderer`) + `ShareSheet` (UIActivityViewController wrapper), wired to a new "Share" button in `TabloView`'s control bar. Verified working in Simulator on iPhone — Share button renders the composition and presents the system share sheet without crashing.
- [x] Watermark on exported/shared images — small "Tablo" text, bottom-right corner, semi-transparent white (`TableSnapshotView.swift`). Simple SwiftUI `.overlay`, code-reviewed but **not yet visually confirmed** in a real exported image — blocked by the iPad Share-sheet bug below. Paid option to remove it (monetization angle) still just an idea, not scoped.
- [ ] **Bug: Share sheet renders blank on iPad Simulator** (found 2026-08-08). Tapping "Share" opens the sheet (dims background, correct chrome), but the `UIActivityViewController` content area shows nothing — no icons, no Cancel button — even after 20+ seconds. Confirmed the underlying image is valid (debug-printed size: 402×874, scale 2.0, not corrupted/zero-size). No errors in the console. Reproduces identically with both `.sheet` and `.fullScreenCover`. Added a `sourceView`/`sourceRect` on `ShareSheet`'s `popoverPresentationController` (`TableSnapshotView.swift`) since that's the standard fix for iPad share-sheet issues and is good practice regardless, but it did **not** resolve this one — root cause still unknown. Not reproduced on iPhone this session (tap input into the iPhone 17 simulator wasn't registering at all — a tooling issue with that simulator instance, not a real test). **Next step: test Share on Kate's iPhone (real device)** to check whether this is Simulator-only (like the camera/barcode features) or a real bug needing a fix.
- [x] **Grid-snap + double-tap-to-straighten** for books on the table — "Snap to Grid" toggle button (`square.grid.2x2` icon) in Style view rounds drag position to a 40pt grid (`CoffeeTableViewIntegrated.swift`); double-tapping a book resets its rotation to 0 without moving it. Both verified working live in Simulator.
- [ ] Quick-swap surface themes: gesture or menu to cycle table textures.
- [x] **Sticker packs** — added "Coffee House" (21) and "Fall Desk" (16) as new tabs in `DecorationView.swift`'s `StickerPickerView`, alongside the existing "Desk Plants" tab (tabs-by-pack UI, `StickerPack` enum). Verified all three tabs render correctly in Simulator. Remaining packs not yet requested: Desk Supplies, Pastels Washi Tape, Witchy Desk Supplies, Ultimate Crystal Collection (94 stickers), plus the 33-card "Fall Oracle Deck" (different vibe, tarot-style — flagged as maybe not fitting the desk-decor theme). Source files in `~/Documents/Curio Design Assets/Stickers/`.
- [ ] More Kate table textures: `~/Documents/Curio Design Assets/Table Surfaces/Kate TableSkapes/` has 7 unimported "-2" variant photos (antiquewood-2, concrete-2, linen-2, marble-2, steel-2 [new material], whiteplaster-2, wood-2) not yet added to the surface picker. Lower priority than stickers per user.
- [ ] Future idea (2026-08-07): a "radio" decoration/object on the table that plays the user's music through their phone (e.g. Apple Music) when tapped — a fun future exploration, not scoped yet.
- [~] **Home screen widget — "Current Read" (started 2026-08-08, in progress).** New `ReadingTableWidgets` extension target added, showing a small (2×2) widget with the most-recently-added book's cover, title, and author (`ReadingTable/Views/Widgets/SmallWidgetView.swift`). No real "currently reading" flag on `Book` yet, so it's standing in for that — **this is expected placeholder behavior, not a bug.** No configuration UI on the widget itself either (can't pick a different book from the widget — by design so far, nothing to fix). Required sharing the SwiftData store with the extension via an App Group (`group.com.adeleroberts.ReadingTable`, entitlements on both targets) — `ReadingTableApp.swift` now opens the model container at a shared store URL and one-time-migrates any pre-existing local database into it so old books aren't lost. `LibraryViewModel` calls `WidgetCenter.shared.reloadAllTimelines()` on add/edit/delete so the widget refreshes. Removed Xcode's unused template boilerplate (`AppIntent.swift`, the "Timer" Control Widget, the "Hello 😀" Live Activity) so only the real widget ships.
  - **Verified 2026-08-08 (Claude, Simulator):** full project (both targets) builds clean with 0 errors, 2 pre-existing unrelated warnings (`TabloView.swift:86`, iOS 26 `UIScreen.main` deprecation). App launches fine against the new shared store with existing books intact.
  - **Verified 2026-08-08 (Adele, real device):** widget successfully added to a real home screen and renders — confirms the App Group / shared-store / widget-extension plumbing all actually works end to end, not just in Simulator.
  - **Fixed 2026-08-08 — crooked cover art in widget.** Root cause: `CustomCoverPicker` in `LibraryView.swift` saved photos picked via `PhotosPicker` as raw `Data`, keeping only the EXIF orientation tag rather than upright pixels. The main app's UIKit-based rendering honors that tag, but WidgetKit's rendering doesn't reliably — so a normal portrait photo (sensor data sideways + a rotation tag, which is how cameras store portrait shots) looked straight in-app but rotated in the widget. Fix: added a `private extension UIImage { normalizedOrientation() }` (`LibraryView.swift`) that bakes the orientation into the pixel data via `UIGraphicsImageRenderer` before saving, so it's correct everywhere regardless of who renders it. Committed as `7f58539` on the `widget-feature` branch. **Not yet visually confirmed** — built a synthetic test JPEG reproducing the exact bug condition (900×600 sideways pixels tagged with EXIF orientation 8, confirmed via `CGImageSourceCopyPropertiesAtIndex`) and loaded it into the Simulator's photo library, but couldn't drive the picker UI to select it — see tooling note below.
  - **New bug found 2026-08-08, reported by Adele testing the real widget (not yet investigated) — watermarked/text-covered artwork showing in the widget.** The widget picked up a book whose stored cover art has visible white text baked into the image itself. Adele's read, which sounds right: this isn't a widget rendering bug like the orientation one above — it looks like the *stored* `coverImageData` for that book already contains the text (most likely an exported/shared Tablo snapshot, which has the "Tablo" watermark from `TableSnapshotView.swift` baked in, that got saved back in as a custom cover via `CustomCoverPicker` at some point). Since there's no way to edit which book/cover the widget shows from the widget itself, the fix has to happen on the book's cover data in the Library. **Next steps once back online:** (1) find the affected book in the Library grid and check/replace its cover via `EditBookView`, (2) confirm whether this was a one-off bad test photo or something the app could actually let happen (e.g. no guard against picking an already-exported Tablo image as a cover) — if the latter, decide whether it's worth guarding against.
  - **Tooling note 2026-08-08 — synthetic Simulator taps not registering.** Across two devices (iPhone 17, iPhone 17 Pro), coordinate-based taps stopped producing any effect on-screen — confirmed even at the home-screen level (tapping the Tablo icon did nothing), while the HOME hardware-button action still worked. This blocked visually confirming both the orientation fix and adding a widget to a Simulator home screen this session. Treated as an environment/tooling issue, not an app bug — matches a similar note logged 2026-08-08 earlier about the widget-gallery jiggle-mode menu. Re-test once tooling is behaving normally.
  - **Git status 2026-08-08:** both widget commits (`77475e3` scaffold, `7f58539` orientation fix) are on the local `widget-feature` branch. `git push`/`git fetch` from Claude's tool session fail with `could not read Username for 'https://github.com'` — no GitHub credentials available in that sandboxed environment, separate from Adele's own network issues. Adele pushed successfully herself via GitHub Desktop (same working copy) while working off a phone tether (no building Wi-Fi) — confirmed by the local repo's own remote-tracking ref, not independently re-verified against GitHub from Claude's side. If a future session finds `widget-feature` local/remote out of sync, trust GitHub over any stale local assumption.
  - Full Tablescape/Library Shelf widget vision (below) is still not started — this is just the first small step.
- [x] Exploration: iPad support and testing. **Confirmed working in Simulator 2026-08-07** — built and launched on iPad Pro 13-inch (M5) simulator. Table view, tap-to-reveal control bar, Library grid, Add Book sheet, and the Stickers picker all render correctly at iPad size (sheets stay centered/sized rather than stretching full-width). No iPad-specific layout bugs found. Noted in passing: the "Library" label in `TabloView.swift`'s control bar truncates to "Libr…" on both iPhone and iPad — pre-existing cosmetic bug, not iPad-related, not yet fixed.
- [ ] Exploration: "nightstand" mode.
- [ ] Exploration: native clock display on the table.

### Future ideas — "app within an app" desk widgets (logged 2026-08-07, explicitly deferred, not scoped)
User brain-dumped a big batch of future decoration/widget ideas, explicitly asked to save for later rather than build now:
- Post-it notes decoration.
- Calendar widget pulling from the iPhone's actual calendar data (would need EventKit + permission).
- A little map/globe showing current location (would need Core Location + permission).
- Weather display widget (would need WeatherKit).
- Music player linked to Apple Music, playable from the table (ties into the existing "radio" idea above — same feature, more detail: wants real playback control, not just a decorative radio).
- Miniature versions of stock iPhone apps as table decorations: alarm, world clock, timer, stopwatch, etc. — a genuine "mini apps on the table" concept.
- Instant-camera decorations (Polaroid/Fuji/Kodak style) — both as decorative artwork (mini camera objects) and as functional print-style photo frames.
- Let a user add their own photo and have it appear inside a blank instant-photo-style frame — Kate reportedly already has blank Polaroid-style artwork ready for this.
- User framed several of these as "maybe future" themselves — treat this whole section as low-priority exploration, not a commitment, until re-raised.

### Future direction — Widgets: Tablescape Mode + Library Shelf Mode (logged 2026-08-07)
**Do not build any of this now — architectural/product direction only, retained for a future dedicated widget effort. Explicitly not part of the current visual-rendering patch.**

Two complementary widget presentation modes are planned:

1. **Tablescape Mode** — a responsive rendering of the user's saved Tablo tabletop and objects (the existing composition view, adapted for widget sizes).
2. **Library Shelf Mode** — a simpler, compact presentation showing the spines of books in the user's library, inspired by the pleasure of viewing a physical bookshelf. Especially important for smaller widget sizes where a full tablescape would be too detailed to read.

Requirements for Library Shelf Mode, once built:
- Generate book-spine representations from each book's stored cover colors, title, and author — no separate spine photography required.
- Preserve enough individuality per spine that the shelf feels like the user's real collection, not a generic placeholder.
- Support small, medium, large, and extra-large widget families wherever Apple makes those sizes available.
- Small widget: only a selected handful of spines.
- Larger widgets: multiple shelves or more of the collection.
- Possible collections to show: Currently Reading, Recently Added, Favourites, or a user-selected shelf.
- Tapping the shelf opens Tablo's Library.
- Use only interactions and refresh behavior officially supported by WidgetKit — no unsupported/custom interaction hacks.
- No conventional controls, tiny unreadable text, or excessive detail — this should read as a beautifully photographed miniature bookshelf, not a database list.
- Lock Screen and StandBy variants should be deliberately simplified designs, not a shrunk-down version of the full bookshelf pushed past legibility.

This builds on the already-logged "Exploration: lock screen / widget support" item above — this is the detailed spec for that exploration, not a separate request.

### Future idea — separate "vision board" app (logged 2026-08-07)
User wants a second, similar app built on the same pattern as ReadingTable but for a vision board instead of a coffee table of books. Kate says she already has the artwork ready for it. Not started, not scoped — would be a new Xcode project, not a feature added to ReadingTable itself.
- Camera and barcode-scanning features need a physical device (cable-connected via Xcode) — the iOS Simulator has no real camera feed.
- There are also 5 unused, unrelated `table-*.imageset` assets already sitting in Assets.xcassets (concrete/linen/marble/travertine/wood, no "Kate" prefix) — orphaned placeholders predating Kate's photos, not wired into any UI. Safe to delete if cleaning up, but left alone unless asked.
