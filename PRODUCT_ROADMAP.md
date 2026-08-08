# MyTablo and Curio Product Roadmap

Last updated: 8 August 2026

This document is a product-level handoff for Adele, Kate, Claude, Gemini, Gigi, and future collaborators. It separates the current MyTablo product from the wider Curio vision so that MyTablo can keep shipping while Curio is explored in its own workspace.

## Product boundaries

- This ReadingTable folder remains the working home for **MyTablo**: its app code, testing notes, release work, and feature roadmap.
- The new Curio folder will hold **company-level and suite-level exploration**: brand strategy, shared principles, possible companion apps, Kate's archive, and longer-term platform ideas.
- MyTablo is the first real Curio product and a useful proving ground, but it should remain understandable and delightful as a standalone app.

## Curio: the wider idea

### Working vision

Curio could become a family of beautiful, calm digital spaces that help people make the technology they already own work for them. Instead of adding another frantic feed or productivity system, Curio would curate information and personal objects already on an iPhone or iPad into spaces people enjoy spending time in.

Kate's digital-planner archive provides the tactile, artistic language: paper, journals, photographs, keepsakes, planners, and decorative objects. Adele's dashboard idea provides the modern utility: calendar, time, weather, health, media, location, and shortcuts. Together, the opportunity is not merely "digital planning" or "widgets"; it is a more personal and humane interface to everyday digital life.

### Early Curio principles

1. **Calm before quantity.** A Curio product should reduce digital noise, not reproduce a busy home screen inside another app.
2. **Personal before generic.** The space should visibly belong to its owner through their books, photographs, handwriting, routines, and choices.
3. **Useful objects, not data panels.** Information should appear as something tactile and understandable: a flip calendar, note, clock, framed photograph, journal, or book.
4. **Arrange once, glance often, touch occasionally.** The experience should remain valuable without constant administration.
5. **Use what the device already knows.** Calendar, photos, health, location, weather, and media can be curated with permission rather than re-entered.
6. **Privacy is part of the atmosphere.** Sensitive information should remain on-device where practical, permissions should be requested only when a feature is added, and shared exports must clearly warn when personal content is visible.
7. **Art and utility have equal status.** Kate's artwork is not decoration applied after the product is built; it is part of the product language.
8. **Build on current capabilities and leave room for future Apple platforms.** The suite should not depend on rumours or one unreleased device form factor.

### Questions for the Curio workspace

- Is Curio the parent company, the suite name, or both?
- What other spaces deserve their own app rather than becoming modes inside MyTablo?
- Which pieces should be shared across the suite: canvas, object model, photo framing, handwriting, themes, permissions, sync, and widgets?
- What is the emotional promise in one sentence?
- Which parts of Kate's planner archive are timeless assets, and which need reinterpretation for current screens?
- How should the suite earn money without making the calm experience feel transactional?
- What should work across iPhone, iPad, widgets, StandBy, and future device formats?

### Possible future product territories

These are brainstorming territories, not committed products:

- A personal tabletop and reading life: MyTablo.
- A journal or paper space for writing, drawing, memory keeping, and planning.
- A vision-board space built around Kate's existing artwork.
- A calm daily dashboard or bedside display.
- Shared visual foundations or object packs that connect the suite without making every app identical.

### Named Curio app ideas to carry forward

The wider Curio exploration should also include the existing app ideas below. Their names and place in the family are recorded now; their exact definitions, audiences, and overlap with MyTablo remain to be worked through with Adele and Kate rather than assumed in this roadmap.

- **White Rabbits**
- **Running Memory**
- **Tally**
- **Body Bank** — a longer-horizon idea to explore after the earlier products and shared Curio foundations are clearer.

When these move into the Curio workspace, give each one a short concept page covering: the human need, the emotional promise, the core daily action, what already exists in the phone or iPad that it curates, Kate's relevant artwork or archive, how it differs from MyTablo, and whether it should be a standalone app or a connected Curio space.

## MyTablo: product definition

### Current promise

MyTablo lets people create a virtual coffee table from their real reading life: books, journals, surfaces, stickers, and personal arrangements that can be revisited or shared.

### Product direction

MyTablo can grow into a **living personal tabletop**. The test for any addition is:

> What would someone lovingly or usefully leave on their real table?

Books, a note, today's plans, a photograph of someone they love, a clock, and a journal all pass that test. A dense grid of unrelated miniature apps does not.

### Four object families

- **Reading:** books, current reads, library shelves, and audiobook shortcuts.
- **Remembering:** sticky notes, journals, handwriting, and calendar.
- **Living:** clock, weather, steps, water, and location.
- **Belonging:** photographs, Polaroids, keepsakes, and personal artwork.

## Where MyTablo stands now

### Core experience built

- Add books by ISBN or manual entry.
- Scan barcodes on a real device.
- Scan, photograph, or upload custom covers.
- Optional background removal for photographed or uploaded covers.
- Arrange books on a virtual coffee table with drag, rotation, scaling, layering, and grid snapping.
- Choose table surfaces and add sticker packs.
- Share a rendered tableau through the iOS share sheet.
- Show the most recently added book in a Home Screen widget.
- Edit or delete Library items, including cleanup of placements when a book is deleted.

### Release preparation

Substantially completed:

- Bundle identifiers corrected.
- Shared-store widget migration made safer against data loss.
- Failed ISBN lookups now show a real error instead of silently creating an "Unknown Book."
- Major table gesture, deletion, sharing, rendering, and layering bugs addressed.

Still to close or confirm with Claude:

- Visually retest background removal on a physical device.
- Confirm the latest custom-cover cropping and manual-entry changes on a physical device.
- Add the Apple privacy manifest.
- Finalise Privacy Policy and Support page copy.
- Apply the identified accessibility labels and minimum tap-target fixes.
- Decide whether iPad remains in the first App Store release if full iPad testing is limited.

The detailed engineering/test history remains in `CLAUDE.md`; this roadmap intentionally records only product-level status.

## Confirmed MyTablo roadmap

### Phase 0: ship a trustworthy first release

- Complete the remaining real-device checks.
- Finish privacy, support, accessibility, and App Store materials.
- Avoid expanding the release scope until the current build is dependable.

### Phase 1: sticky notes

Purpose: introduce the first editable, data-bearing tabletop decoration.

First version:

- Add a note, enter plain text, and choose from a small set of paper colours.
- Drag, rotate, resize, layer, edit, and delete it using the familiar decoration interactions.
- Keep typography legible as the note is resized.
- Do not add checklists, rich formatting, reminders, or collaboration yet.

Why it matters beyond one feature: its reusable text-and-decoration foundation can later support journal paper, captions, labels, and other planner objects.

### Phase 2: calendar

Purpose: make the tabletop useful at a glance without turning it into a calendar application.

First version:

- A Kate-designed flip-calendar object.
- Show today and the next two or three events.
- Let the user select which calendars contribute events.
- Offer a privacy mode that hides event titles.
- Request calendar access only when the user adds the object.
- Provide a graceful decorative or setup state if access is declined.

Keep event creation, complex agenda management, and scheduling outside the first version.

### Phase 3: personal photographs

Purpose: make a tableau emotionally personal, not merely styled.

First version:

- Choose a photograph from the user's library.
- Place it inside one of Kate's Polaroid or photo-frame designs.
- Drag, rotate, resize, layer, replace, and delete it like other objects.
- Store it locally.
- Include it in shared tableau images, with a clear share-time reminder that visible personal photographs will be included.

Possible later frames: torn-edge print, portrait frame, photo-booth strip, and a photograph tucked into an open journal.

### Phase 4: paper and time

- Writable journal-paper decorations using the sticky-note text foundation.
- A simple clock and optional world-clock objects.
- A decorative alarm showing a chosen time; do not imply control of Apple's Clock alarms.
- Freehand journal or tabletop drawing with Apple Pencil or a finger as a separate, larger feature.

### Phase 5: ambient dashboard objects

- Step count.
- Weather.
- Location or a small map/globe.
- Water tracking, beginning as a simple MyTablo counter before considering health-data syncing.

Each permission should be requested at the moment the corresponding object is added, never as a bundle of unexplained prompts during onboarding.

### Phase 6: media

- Begin with a manually chosen audiobook cover or object that opens the user's chosen listening app.
- Explore Apple Music selection and playback later; it carries substantially more authorization, subscription, interface, and playback-state work.

### Separate future widget effort

- **Tablescape mode:** render a simplified version of the user's saved tabletop at supported widget sizes.
- **Library shelf mode:** generate attractive book spines and shelves from the user's library.
- Add an explicit favourite or Currently Reading choice so widgets are not limited to the most recently added book.
- Treat Lock Screen and StandBy designs as deliberately simplified products, not shrunken copies of the full tabletop.

## Interaction architecture to preserve

MyTablo should retain two distinct modes:

- **Edit mode:** add, configure, move, resize, rotate, layer, and delete objects.
- **Live mode:** a calm, glanceable tabletop with editing chrome hidden and only intentional object interactions enabled.

A later Display Mode may hide all controls and optionally keep the screen awake, but normal screen sleep should remain the default for battery health. Calendar and health values should have privacy-hiding options in this mode.

## Reusable foundation for Claude

The current decoration model is primarily image-based. Sticky notes, calendars, photographs, clocks, and health objects are typed decorations containing their own data and configuration. The implementation should therefore introduce a migration-safe, reusable data-bearing decoration foundation rather than an unrelated storage system for each feature.

Likely shared capabilities include:

- Common placement, scale, rotation, z-order, selection, and deletion.
- A decoration type and migration-safe default data.
- Editing/configuration sheets appropriate to each object.
- Static snapshot rendering for sharing.
- Privacy-aware export behaviour.
- Conservative refresh rules for live information.

## Near-term decision log

- MyTablo continues now; it does not wait for the whole Curio strategy.
- Sticky Notes comes first.
- Calendar comes second.
- Personal photo frames are enthusiastically approved and follow Calendar, unless implementation reuse makes it sensible to develop them alongside Sticky Notes.
- MyTablo should become a living tabletop, not a generic grid of mini-widgets.
- Curio exploration moves to its own folder once Adele begins sharing Kate's files and wider company material.

## North-star test

> Open MyTablo and, within three seconds, know what matters today while still feeling that the table unmistakably belongs to you.
