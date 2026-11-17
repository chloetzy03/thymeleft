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
| Add / edit item manually (emoji preview, quick dates, validation) | 2 | Done |
| Expiry reminders (local notifications), per-item override, friendly permission explainer | 3 | Done |
| Settings in the Me tab: reminder time/days, date format, red/amber thresholds | 3 | Done |
| Item photos (camera or library) instead of emoji | 4 | Done |
| Scan expiry date (live camera, or a photo of the date), keep a pack photo | 5 | Done (live camera needs a real-iPhone check) |
| Recipe suggestions from what you have (TheMealDB), use-up-first or best-match, offline saved recipes, full detail screen | 6 | Done |
| Home tab: time-aware greeting, use-soon tiles, "What can I cook?", saved-from-the-bin counter with optional money estimate; swipe Used it / Threw away / Delete | 7 | Done |
| Optional price per item; Best before / Use by with clearer past-date wording | 7.5 | Done |
| Real-iPhone testing and fixes (round 1: scanner day bug, photo, dark mode, Scan tab as camera screen) | 8 | Round 1 done; reminders confirmed working on a real iPhone |
| Accessibility audit (contrast, largest text, VoiceOver labels) | 9 | First pass done; re-check on device |
| App icon: the smiling fridge with a sprout, in light, dark and tinted versions (sources in docs/design/icon-source) | 10 | Done (Sprig mascot art can follow later) |
| Recipe search (by dish or ingredient) and a fuller Home screen (shortcuts, This week strip, Tonight's idea) | 11 | Done |
| Simplified Chinese: every screen, Chinese food names (emoji, recipe matching, search), Chinese dates on packs, camera permission text | 12 | Done (Chinese scanning needs a real-phone check) |
| First-run welcome (3 short slides: Scan, Swipe, Remind) | 13 | Planned |
| Release prep: privacy policy, privacy manifest, screenshots (English and Chinese), App Store text (English and Chinese), TestFlight | 14 | Planned |
| Tip jar | Later | Planned |
| "Thyme Left Plus" (iCloud sync, family sharing, widgets, themes) | Later | Idea |
| Barcode lookup | Later | Idea |

## Home and "saved from the bin" (how they behave)
- The app opens on Home: "Good morning/afternoon/evening, chef!", up to three use-soon tiles, a big "What can I cook?" button and a monthly counter.
- Swiping a pantry row offers Used it, Threw away and Delete. Only "Used it" counts as food saved; "Threw away" is remembered but not counted; Delete (mistakes) is neither. A long swipe never deletes.
- Money is an estimate (items used this month x an average value you choose in Me, in your own currency) and can be turned off.
- Privacy: history is only names and dates, kept on the phone.
- Selling point: "See the food you've rescued, not just the food you've lost."

## Languages
- English and Simplified Chinese (简体中文). The app follows the phone's language; iOS also lets people pick a language for just this app.
- Chinese food names are understood (about 170 common foods): emoji, recipe matching and search all work with "牛奶", "鸡蛋", "三文鱼" and so on.
- Chinese dates on packs are scanned: `保质期至2027年11月5日`, `请在2027年3月8日前食用`; production dates (`生产日期`) are ignored.
- **Honest limits for the website and App Store text:** recipe names and steps come from TheMealDB and stay in English; unusual foods (e.g. 榴莲) get the plate emoji and are not matched to recipes.
- To add a language later: translate `Localizable.xcstrings` and `InfoPlist.xcstrings`, then run `scripts/check_localization.py`.

## Price and date type (how they behave)
- Optional price per item; "Saved from the bin" adds the real prices of items you used, falling back to your average value for items without one.
- Each item is "Best before" (quality) or "Use by" (safety). Past use-by: "Past use-by, do not eat". Past best-before: "Past date, check before eating". The app is a reminder tool, not a food-safety authority (say so on the website and App Store text).

## Recipes (how they behave)
- The Recipes tab suggests dishes built from your food. "Use up first" favours recipes that rescue items closest to expiring (but a recipe needing a huge shop ranks lower); "Best match" favours the fewest missing ingredients.
- Expired food is never suggested. Water, salt, pepper and oil are assumed to be in your kitchen.
- Each recipe shows what you'd use, what's missing, a photo, ingredients ticked as have/need, and steps. A link to the original (and video) appears when the recipe has one.
- Works offline: every recipe it fetches is saved on the phone (up to 150). With no internet it shows saved recipes plus a note.
- Credit: "Recipes from TheMealDB" is shown on both screens.
- TODO before release: confirm TheMealDB's terms for a commercial app and likely buy their supporter key; the free test key is for development.

## Scanning (how it behaves)
- Scan tab opens a new item with the scanner running; the Add/Edit form also has a "Scan the date on the pack" button.
- Live camera uses Apple's built-in text scanner. The date must be seen twice in a row before it is trusted. No camera (or permission off)? Choose a photo of the date instead.
- The user always confirms: the card shows the date, "Expires in N days", the line it was read from, and a one-tap swap when day/month are ambiguous (03/04/26). Optional "keep photo" saves the pack picture as the item's photo.
- Understands EXP / BEST BEFORE / USE BY, month names, month-and-year only (= end of month), and ignores MFG/production dates. Fixes common misreads (O for 0, I for 1).
- 100% on-device (Apple Vision), works offline, nothing uploaded.

## Photos (how they behave)
- Tap the tile in the Add/Edit form: take a photo, choose from the library, or remove it. No photo = the emoji (auto-guessed from the name).
- Photos are shrunk to about 600 px and stored privately on the phone (never uploaded). The library picker shows only what the user selects, so no photo-library permission is needed. The camera asks permission in plain language.
- Replacing, removing or deleting an item also deletes the old photo file, so storage never fills with leftovers.
- Selling point: "Know what it looks like, at a glance. Photos never leave your phone."

## Reminders (how they behave)
- Default: 1 day before at 9:00 AM; both editable in Me. Each item can override (Same day / 1-3 days / 1 week / Never).
- Permission is asked only after the user first saves an item that would get a reminder, with a one-time plain-language explainer. Never at launch. If denied, a banner in Me links to iOS Settings.
- Reminders are local to the phone (no server, no account), which supports the privacy-first promise.
- iOS holds at most 64 pending reminders, so the soonest 60 are scheduled and topped up whenever the app opens or something changes.

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
- [x] Camera usage description (plain-language reason)
- [x] Notification permission shown at a sensible moment (not on first launch)
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
