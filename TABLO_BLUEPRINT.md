# Tablo

Editorial redesign brief. Parked 15 Aug 2026. Open this folder in a fresh chat before touching Xcode.

Tomorrow’s launch brief is in `Brief.md` (Tablo: The Autumn Launch Anchor). Same product. Use both. Do not start a second app.

Tablo is already built natively in Xcode. Transform the visual look without rewriting underlying logic. Protect core functionality.

Reference look: White Rabbits, Oura-grade, Apple-editorial.

## 1. Extract and lock in the design system tokens

Before touching any code in Xcode, port the design DNA from White Rabbits into a reusable Swift / SwiftUI styling foundation:

- **Colour palette & tokens:** Semantic colour extensions (matte cream backgrounds, warm ink text, soft gold/cream accents) so everything shifts cleanly between light and dark modes.
- **Typography hierarchy:** Custom or system font modifiers for a clean editorial look. Large, elegant serif headers paired with ultra-clean sans-serif body text and generous tracking / line spacing.
- **Card & radius components:** Reusable container view for cards (16pt to 24pt corner radii, soft micro-shadows, subtle border lines) so every screen inherits that tactile, high-end look.

Studio craft bar also applies: semantic tokens only, no one-off hex in views, generous whitespace, haptics on meaningful taps.

## 2. Audit Tablo's views vs White Rabbits

Map Tablo’s existing screens side-by-side with White Rabbits:

- **Preserve core logic:** Keep all existing data models, navigation stacks, and local storage / SwiftData handlers intact.
- **Skin-deep editorial refresh:** Overhaul the UI layer screen-by-screen. Swap standard buttons for tactile chips, replace generic text fields with clean open-invitation journaling blocks, and centre hero elements where appropriate.

## 3. Establish a reusable Studio template in Xcode

Extract these styling components into a local Swift package or a core UI template folder. Drop the studio styling kit into new or existing apps so they belong in the same luxury family.

## How to start

When ready on this Mac:

1. File → Open Folder on `Studio/Tablo`.
2. Start a fresh chat there.
3. Drop the current Tablo views or Xcode project into that folder if they are not here yet.
4. Map exact code refactors screen by screen. Do not rewrite data or navigation.
