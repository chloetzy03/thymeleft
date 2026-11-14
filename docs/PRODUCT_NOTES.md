# thyme left. – Product Notes

Raw material for the future GitHub page / App Store listing. Update it as features land.

## One-liner
**Know what's about to expire. Cook it before it's gone.**
Tagline: *"A little thyme goes a long way."* / *"Make good food go further."*

## Who it's for
People who throw away groceries because they forgot the date, and want an easy answer to "what should I cook?".

## Why it's different (selling points)
1. **Use-it-first recipes.** Recipes ranked by what is about to expire, not just what you own.
2. **Scan, don't type.** Point the camera at the printed date (on-device text recognition, works offline).
3. **Private by design.** Data stays on the phone. No account, no ads, no tracking.
4. **Free and calm.** No paywall on core features. Friendly reminders, not nagging.
5. **Mascot (Sprig).** Memorable character for empty states and reminders.
6. **"Saved from the bin" counter.** Shows food and money rescued; shareable.

## Feature list & status
| Feature | Milestone | Status |
|---|---|---|
| App skeleton, theme (light + dark), 4-tab bar | 0 | Done |
| Pantry list with expiry badges, location filters, swipe to delete, dark mode, VoiceOver | 1 | Done |
| Add / edit item manually | 2 | Planned |
| Expiry reminders (local notifications) | 3 | Planned |
| Scan expiry date with camera | 4 | Planned |
| Recipe suggestions (TheMealDB) | 5 | Planned |
| Polish: icon, empty states, tests, accessibility | 6 | Planned |
| Tip jar | Later | Planned |
| "Thyme Left Plus" (iCloud sync, family sharing, widgets, themes) | Later | Idea |
| Barcode lookup | Later | Idea |

## Design
- Direction: **Sage & Cream** (see `docs/design/mockups-v3.html`).
- Fonts: one sans-serif everywhere for now; serif option available per role in `Theme.Typography`.
- Palette: cream `#FAF6EA`, sage `#E6EDDB`, deep green `#2F5A3E`, plus soft red / amber / green for expiry status. Dark mode supported.
- Status is always shown as colour **and** words (accessibility).

## Monetisation
Free, no ads. Tip jar now; optional "Plus" tier later. Core features (scan, reminders, recipes) stay free.

## Competitors (from memory, verify before publishing)
NoWaste, Pantry Check, Fridgely, Cooklist, Kitchen Pal. Related: Too Good To Go, Olio, Mealime.

## App Store checklist
- [ ] Apple Developer Program membership (~US$99/year)
- [ ] Check name availability / trademark for "thyme left"
- [ ] Camera usage description (plain-language reason)
- [ ] Notification permission shown at a sensible moment (not on first launch)
- [ ] Privacy policy URL (can be a GitHub Pages page)
- [ ] Privacy manifest (`PrivacyInfo.xcprivacy`) and App Privacy answers
- [ ] TheMealDB: check terms for commercial use and attribution; may need their paid key for release
- [ ] Accessibility: Dynamic Type, VoiceOver labels, contrast, no colour-only meaning
- [ ] App icon (1024×1024) and screenshots for required device sizes
- [ ] No placeholder / unfinished screens (remove "coming soon" tabs before release)
- [ ] Support URL and contact email
- [ ] TestFlight beta before submitting

## Website / GitHub Pages ideas
Hero (tagline + app screenshot), 3 benefit blocks (scan, use-it-first recipes, private), mascot, screenshots, privacy policy page, App Store badge, "buy Sprig a coffee" link.
