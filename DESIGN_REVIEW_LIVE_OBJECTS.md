# MyTablo Live Objects — Design Review and Reset

**Date:** 8 August 2026  
**Decision owners:** Adele and Kate  
**Implementation:** Claude  
**Design support:** Gigi/Codex

## Outcome

The clock, calculator, weather, and music experiments prove that live utilities can exist on the table, but their current visual treatment is not approved. They read as generic white app-launcher tiles and disrupt the tactile, editorial quality of the books, plants, photographs, calendar, and notes.

Do not polish the present white-square designs into release features. Treat them as functional prototypes and redesign their object metaphors first.

## Product rule

**MyTablo contains useful physical-feeling objects, not miniature app icons or generic widgets.**

Each live object should have three layers:

1. A beautiful, tactile object or piece of artwork that belongs on a real table.
2. A restrained live-data layer, such as clock hands, temperature, album artwork, or a calculator display.
3. A clear interaction layer that works from the normal MyTablo screen.

Static artwork can provide the casing, texture, shadows, and personality. SwiftUI should place the live information and controls precisely above it. This gives us the beauty of Kate/Gigi-generated artwork without sacrificing real functionality.

## Interaction rule

- **Normal Table mode:** live objects are usable. A tap opens or operates the object; essential music controls may work directly on the table.
- **Style mode:** add, move, resize, rotate, configure, and remove objects.
- A user must not have to enter Style mode merely to use a calculator, play music, inspect weather, or interact with a clock.
- Editing gestures and everyday-use gestures must be kept distinct so tapping an object does not accidentally move it.

## Object directions

### Clock

Replace both current versions. The digital clock currently formats incorrectly (for example `18:3` rather than `18:03`), and the analogue face is not visually acceptable.

Explore a small family of properly art-directed objects:

- a refined mid-century desk clock;
- a brass travel clock;
- a softly lit digital bedside clock;
- later, a world-clock or alarm variation.

Use artwork for the casing and face, with accurately positioned live hands or digits above it. Digital time must use two-digit minutes and stable-width numerals. The clock should remain attractive at its smallest supported size.

### Calculator

Replace the white launcher card and generic white modal. The table object should resemble a desirable physical pocket or desktop calculator with tactile keys and a readable display. Tapping it from normal Table mode may expand the same object into a usable calculator, preserving its materials and visual identity rather than switching to an unrelated stock panel.

### Weather

The current blank white `--°` card is both a functional failure state and an aesthetic failure. First diagnose WeatherKit separately from the redesign.

Possible object metaphors:

- a small ceramic weather tile;
- an illustrated forecast card;
- a vintage barometer with a small temperature label;
- a tiny window or framed landscape that changes with conditions.

The failure state should be intentional and helpful—such as a tasteful location-permission prompt—not a broken-looking empty object.

### Music

Opening the full Apple Music app proves the deep link but does not deliver the intended MyTablo experience. Explore a tabletop radio, record player, cassette player, or album sleeve as the visual object. The ideal first useful version shows current artwork/title and offers play/pause and skip directly from normal Table mode. Opening Apple Music can remain a secondary action. Confirm the feasible MusicKit playback and authorization path before final scoping.

## Wider visual-system requirements

- Define a shared lighting angle, shadow softness, camera angle, and apparent scale for all objects.
- Avoid default SF Symbol-on-white-card treatments on the tabletop.
- Avoid generic system sheets when an expanded version of the object can provide the experience.
- Preserve clarity and accessibility: adequate contrast, Dynamic Type where appropriate, VoiceOver labels, and minimum tap targets even when the visible object is small.
- The crowded row of identical black Style buttons needs a later information-architecture pass—prefer a beautiful object drawer/library with categories over an ever-growing toolbar.

## Immediate engineering recommendation

1. Keep the implementations available as prototypes, but remove or hide the four unapproved live objects from the release-facing picker while the redesign is underway.
2. Fix and verify the weather data path independently.
3. Build one exemplary live object end-to-end before multiplying the pattern. Recommended exemplar: the desk clock, because it requires no permission and proves artwork-plus-live-overlay rendering.
4. Get Adele and Kate's visual approval on that object before adapting the pattern to calculator, weather, and music.

## British Table Favourites pack and reusable extraction tool

The first 20-item prototype pack is ready at:

- `StickerPacks/BritishTableFavourites-Prototype/`
- `StickerPacks/BritishTableFavourites-Prototype.zip`

Every sticker is a separately named, genuinely transparent 1024×1024 PNG. The reusable contact-sheet extractor is:

- `Tools/extract_food_sticker_pack.py`

It currently expects the approved 1408×768, 5×4 contact-sheet format. It removes the numbered labels and neutral background, centres each subject on a transparent square canvas, creates a visual alpha-quality-check sheet, and packages the 20 PNGs into a ZIP. It can be generalized into a Kate-and-Adele-friendly Curio utility later.

## Pack business model to explore

- Include a generous, beautiful free starter collection.
- Offer optional curated themed packs, such as British Table Favourites, Afternoon Tea, Sunday Morning, Christmas Table, Italian Supper, and Kate's Desk.
- Let customers vote on or request future themes; Adele and Kate retain editorial control.
- Consider artist collaborations and seasonal drops.
- Much later, explore a moderated “design your own pack” AI feature. Do not begin with uncontrolled generation: quality review, provenance, commercial-use terms, brand/character avoidance, safety, and consistency all need a deliberate workflow.
- Confirm the current App Store purchase rules and commercial artwork terms before implementing paid digital packs.

The commercial promise is not merely “more stickers.” It is a growing, collectable world of beautifully art-directed objects that continue making each person's table more personal.
