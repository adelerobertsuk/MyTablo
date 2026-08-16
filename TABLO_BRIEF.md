# Tablo: The Autumn Launch Anchor Brief

Saved 15 Aug 2026 for tomorrow (slot 4). Do not start this until Adele opens a new chat and asks to begin.

**Role:** Product Designer & Frontend Architect

**Task:** Finalize the virtual tablescape and book-styling application, ensuring the user interface is completely polished, editorial, and ready for its autumn back-to-school launch window.

## Core constraints and specs

### Design aesthetic

Minimalist, cinematic, and editorial. Think clean grid systems, high-end photography framing, and sophisticated neutral colour palettes.

Studio craft bar also applies: world-class only (Oura / Apple grade). Generous whitespace, 16–24pt radii, soft shadows, glass only where it earns its keep. System SF fonts, light titles, medium body. Semantic colour tokens only. No one-off hex in views. Haptics on meaningful taps.

### Why it exists

Kate has a huge archive of digital planners and stickers. She made them years ago, before it was cool. It is cool now.

MyTablo is a beautiful way to display books. Adele has not seen that before. Then the sticker packs sit on top of the table. That is the product. Not a generic “asset manager.”

### Core functionality

- Seamless tablescape composition styling
- Books on the table, looking like a real coffee table
- Kate’s packs, grouped clearly (planners, stickers, papers)
- A frictionless export / sharing view for digital products

Protect the working product. Do not rewrite data models, navigation, or storage unless Adele asks.

### Performance

Fast, smooth state management for organizing visual assets without UI lag.

## What already exists

Tablo is already built natively in Xcode (SwiftUI + SwiftData). Official name: **MyTablo**. Tablo is fine in conversation.

Working project (iCloud, not this Studio folder yet):

`~/Library/Mobile Documents/com~apple~CloudDocs/Documents/Documents - Adele’s MacBook Pro/MyTablo/`

Key screens and logic to keep:

- `TabloView.swift` / `CoffeeTableViewIntegrated.swift`: table composition, drag / scale / rotate, share
- `CoffeeTableCompositionViewModel.swift`: arrangements without lag
- `DecorationView.swift`: sticker and styling packs (including Papers and Retro Paper)
- `LibraryView.swift`: books
- `TableSnapshotView.swift`: export / share framing

This Studio folder currently holds briefs only. Tomorrow’s chat should open the real Xcode project, not start a second app.

The earlier editorial pass in `Blueprint.md` still stands: skin Tablo to White Rabbits / Oura-grade, extract tokens first, do not rewrite underlying logic.

## Punch list for the next chat

1. File, Open Folder on `Studio/Tablo`.
2. Start a fresh chat there.
3. Read `Brief.md` and `Blueprint.md`.
4. Open the existing MyTablo Xcode project. Do not create a new app.
5. Lock design tokens (neutral editorial palette, type, cards) before restyling screens.
6. Polish tablescape composition so it feels cinematic and framed.
7. Make styling packs scan as clear groups, not a flat pile.
8. Polish the export / sharing view for a frictionless digital product shot.
9. Keep asset organizing snappy. No UI lag.

## How to start

When ready on this Mac:

1. File → Open Folder on `Studio/Tablo`.
2. Start a fresh chat there.
3. Paste: "Read Brief.md and begin the Tablo autumn launch polish pass."
