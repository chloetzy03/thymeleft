# Learning Log – thyme left.

We are building the app first, then going back through this file as lessons.
Each entry says **what** was done, **why**, and the idea behind it in plain words.
At the end of each entry there are check-your-understanding questions.

---

## Before coding: planning decisions
| Decision | Choice | Why (plain words) |
|---|---|---|
| Name | thyme left. | Pun on "time left"; the herb gives us a mascot |
| UI | UIKit, built in code | Classic VIPER is written with UIKit; no storyboards means fewer hidden settings |
| Architecture | VIPER + SOLID | Every screen is split into small jobs so nothing becomes a giant file |
| Storage | SwiftData behind a protocol | Easy database now; can be swapped later without touching screen logic |
| Recipes | TheMealDB (free API) | Real recipes, no sign-up for development |
| Git | One branch per feature, merge into `main` | If a feature goes wrong, `main` stays safe |
| Design | Sage & Cream (`docs/design/mockups-v3.html`) | Closest to your reference images |

**VIPER in one picture (restaurant analogy)**
- **View** = waiter: shows things, passes your taps along, does no thinking
- **Interactor** = chef: the real logic (e.g. "how many days until this expires?")
- **Presenter** = manager: takes the chef's result and prepares it for the waiter
- **Entity** = ingredients: plain data describing ONE thing (e.g. a pantry item)
- **Router** = host: decides which table (screen) comes next

---

## Milestone 0 – Project setup (`chore/project-setup`)

### What I did
1. **Deleted the SwiftUI leftovers** (`ContentView.swift`, the empty `ViewController.swift`). We are using UIKit, so these were dead weight.
2. **Moved app start-up files into an `App/` folder** (`AppDelegate`, `SceneDelegate`). Tidy folders = easier to find things.
3. **Added `.gitignore`** so Xcode's personal/temporary files never get saved to Git.
4. **Created `Common/Theme/Theme.swift`**: the single place for all colours and fonts.
5. **Created `RootTabBarController`**: the bottom bar with Home / Scan / Pantry / Recipes.
6. **Created `PlaceholderViewController`**: a temporary "coming soon" screen for each tab.
7. **Wrote `docs/PRODUCT_NOTES.md`**: features and App Store to-dos, for your future website.

### Concepts in plain words
- **Theme file (single source of truth).** Instead of typing a colour code on every screen, every screen asks `Theme` ("give me the brand green"). Change it once, the whole app changes. This is the **Single Responsibility** idea from SOLID: one file, one job (looks).
- **Typography "roles".** Screens say "I need a *screen title*", never "I need size 28 bold". To switch a role to the serif font later, edit one spot in `Theme.Typography.design`.
- **Light/dark mode colours.** `UIColor.dynamic(light:dark:)` holds two versions of a colour; iOS picks the right one automatically.
- **Dynamic Type.** `UIFontMetrics` lets text grow or shrink when the user changes their phone's text size. This is an accessibility feature App Review likes.
- **`UITabBarController`.** Apple's ready-made bottom tab bar. We just hand it a list of screens.
- **Placeholder screens.** Build the "house frame" first and fill in rooms later, so we can always run the app.
- **Programmatic UI.** `SceneDelegate` creates the window and sets `RootTabBarController()` as the first screen, with no storyboard needed.

### A gotcha worth remembering
On iOS 26 the new floating tab bar **ignores the icon colour** you ask for (the labels obey, the icons stay black). The fix is to give it icons that are already painted the right colour (`withTintColor(..., renderingMode: .alwaysOriginal)`), and repaint them when the phone switches between light and dark mode. Setting the icons *after* the bar was built made the labels jump down, so we set them when each tab is created.

### Commit messages used
- `chore: add .gitignore for Xcode temporary files`
- `feat: add Theme (colours and font roles) with light and dark mode`
- `feat: add tab bar skeleton with placeholder screens`
- `docs: add product notes and learning log`

Pattern: `type: short summary`. `feat` = new feature, `chore` = housekeeping, `docs` = documentation.

### Check your understanding
1. Why does the app have a `Theme` file instead of putting colours on each screen?
2. If you wanted only screen titles to become serif, how many places would you edit?
3. Why did we build placeholder screens instead of waiting for the real ones?
4. Which VIPER part creates the *first* screen the user sees? (Hint: it is not one of the five letters yet. We'll see where it lives when we build our first module.)

---

## Milestone 1 – Pantry list (`feature/pantry-list`)

This is our first full **VIPER module**. Read it top to bottom: it is the pattern every later screen copies.

### What you can do now
See your items sorted by soonest expiry, grouped into "USE SOON" and "FRESH", with colour badges, filter by Fridge / Pantry / Freezer / Counter, swipe left to delete, and see a friendly empty state. (Debug builds start with sample food. We delete that once "Add item" exists.)

### The files, in the order data flows
| Part | File | Job in plain words |
|---|---|---|
| **Entity** | `Entities/PantryItem.swift` | One item: name, quantity, where, expiry date. Pure facts. |
| Entity | `Entities/ExpiryPolicy.swift` | The rulebook: "red when 1 day or less, amber up to 5, else green". |
| Entity | `Entities/ExpiringItem.swift` | An item plus its countdown and colour status. |
| Service | `Services/Pantry/PantryRepository.swift` | A *job description*: "something that can save, load and delete items". |
| Service | `SwiftDataPantryRepository.swift` | The real worker that stores items on the phone. |
| Service | `InMemoryPantryRepository.swift` | A pretend worker for tests, and a safety net. |
| **Interactor** | `Modules/PantryList/PantryListInteractor.swift` | The chef: loads, filters, counts days, sorts. |
| **Presenter** | `PantryListPresenter.swift` | The manager: turns results into sections, words and emoji. |
| **View** | `View/PantryListViewController.swift` + cell/header | The waiter: draws it and passes taps along. |
| **Router** | `PantryListRouter.swift` | The host: goes to the "Add item" screen. |
| Contracts | `PantryListContracts.swift` | Who may ask whom for what (all the protocols in one place). |
| Builder | bottom of `PantryListRouter.swift` | Assembles the five parts and introduces them. |
| Wiring | `App/AppContainer.swift` | Builds the real database/clock/etc. once, at start-up. |

### How one tap travels (follow the arrows)
Tap the "Fridge" chip -> **View** tells **Presenter** `didSelectFilter(1)` -> Presenter tells **Interactor** `loadItems(in: .fridge)` -> Interactor asks the **Repository** for items, works out countdowns, sorts -> Interactor reports `didLoad(items)` to the Presenter -> Presenter builds `PantrySectionViewModel`s -> View draws them.
Notice the View never talks to the Interactor, and the Interactor never talks to the View.

### Concepts in plain words
- **Entity vs the database record.** `PantryItem` is plain data the whole app uses. `PantryItemRecord` is SwiftData's private copy. We convert between them so the rest of the app never needs to know SwiftData exists.
- **Protocol = job description.** `PantryRepository` says what must be possible, not how. The Interactor only knows the description. (**SOLID D**: depend on the description, not the specific worker.)
- **View models.** The Presenter hands the View ready-to-show text (`badgeText: "3 days"`), so the View needs zero logic.
- **`weak`.** Two objects that hold each other tightly can never be cleaned up from memory. `weak` means "I know you, but I won't hold you." The Presenter holds the View weakly.
- **Composition root (`AppContainer`).** One place that builds the real parts and hands them out (this is "dependency injection": tools are *given* to a screen instead of the screen grabbing them).
- **`DateProviding`.** We ask a clock object for "now" instead of calling `Date()` everywhere. In tests we give it a frozen clock, so tests never break just because the day changed.
- **Spies in tests.** To test the Presenter alone we plug in pretend View/Interactor/Router objects that simply write down what they were told. No real screens or database needed.
- **Accessibility.** Each row reads as one sentence in VoiceOver ("Milk, Fridge, quantity 1, expires tomorrow"), status always has words not just colour, text grows with the phone's text size.
- **Safety net.** If the database fails to open, the app falls back to in-memory storage instead of crashing.

### SOLID, where you can see it
| Letter | Where | Plain words |
|---|---|---|
| **S** Single responsibility | `ExpiryPolicy`, `ExpiryTextFormatter`, `Theme`, `FoodIconProvider` | Each type does one job |
| **O** Open/closed | `EmojiFoodIconProvider` is behind `FoodIconProviding`; policy numbers are injected | Add new behaviour by adding new code, not editing old |
| **L** Liskov | `InMemoryPantryRepository` and `SwiftDataPantryRepository` are interchangeable | Any stand-in must behave like the original |
| **I** Interface segregation | View, Presenter, Interactor input/output are separate small protocols | Nobody is forced to know methods it never uses |
| **D** Dependency inversion | Interactor depends on `PantryRepository`, not SwiftData | High-level logic doesn't depend on low-level details |

### Bugs found and fixed along the way
- Emoji lookup: "Eggplant" matched "egg" first and showed an egg. Fix: specific words go above general ones. Same idea for "peas" vs "peach/pear".
- Removed over-greedy keywords ("can" matched "pancake").
- Reminder: the order of items in a list can be part of the logic. We covered this in tests.

### Commit messages used
- `feat: add pantry entities and expiry policy with tests`
- `feat: add pantry storage (repository protocol, SwiftData, in-memory)`
- `feat: add pantry list logic (interactor, presenter, router) with tests`
- `feat: add pantry list screen (cells, filter chips, empty state)`
- `feat: wire pantry list into the app with AppContainer and debug sample data`
- `docs: add milestone 1 notes to learning log`

### Check your understanding
1. If we replaced SwiftData with a plain text file, which files would change? Which would not?
2. Why does the Presenter hand the View `"3 days"` instead of the number 3?
3. Why do we give the Interactor a `DateProviding` instead of letting it call `Date()`?
4. A user says "my expired yoghurt isn't at the top!" Which VIPER part would you check first, and why?
5. Why is `PantryListPresenter.view` marked `weak`?

---

## Testing notes (`chore/xctest-aaa`)

### What changed
- Converted all tests from **Swift Testing** (`@Test`, `#expect`) to **XCTest** (`XCTestCase`, `test_...` methods, `XCTAssertEqual`), because that is the style you learned. They check the same things; only the vocabulary differs. (Xcode's new-project template defaults to Swift Testing; UI tests are always XCTest.)
- Every test now follows **Arrange / Act / Assert**: set things up, do the ONE thing being tested, check the result.
- Test names read like a sentence: `test_<thing>_<situation>_<expected result>`, e.g. `test_loadItems_withMixedDates_sortsSoonestFirstWithExpiredOnTop`.
- Deleted the empty Xcode template test (`thyme_leftTests.swift`).

### A crash worth remembering ("thyme left quit unexpectedly")
Running the tests made macOS show a "quit unexpectedly" crash for the app, and the simulator dropped out. The crash report pointed at `PantryListPresenter.__deallocating_deinit` inside the test, i.e. the crash happened when a test finished and freed a main-actor object. The new Xcode "default to MainActor" setting makes our classes main-actor-bound, and freeing them at the end of a plain (non-async) XCTest method crashed the Swift runtime. Marking those test methods `async` fixes it (27 tests pass, zero crash reports). Rule of thumb: in this project, tests that create `@MainActor` objects should be `async`.
Watch-out for Milestone 2: when a screen is closed its Presenter is freed too, so we will double-check that closing a screen in the real app does not crash.

### Check your understanding
1. In your own words, what do Arrange, Act and Assert each mean? Point to them in one test.
2. Why does a test have one Act and not several?
3. What is the difference between a "spy" and the real object it replaces?

## Milestone 2 – Add and edit items (`feature/add-edit-item`)

Second VIPER module. Same five parts as Milestone 1, so this one is the "do it again" lesson.

### What you can do now
Tap **+** (or the empty-state button) to add an item, or tap any row to edit it. The form has a name with a live emoji preview, quantity (1-99), a storage-location menu, an expiry date picker and quick-date chips (Tomorrow / 3 days / 1 week / 1 month). Bad input shows a friendly message instead of saving.

### The files
| Part | File | Job in plain words |
|---|---|---|
| Entity | `Entities/PantryItemDraft.swift` | The form's rough copy, plus the rules (`PantryItemRules`) and the reasons it can be rejected (`ItemValidationError`) |
| **Interactor** | `Modules/AddEditItem/AddEditItemInteractor.swift` | Checks the rules (trim the name, 1-40 characters, quantity 1-99), then saves. Keeps the original id and "date added" when editing |
| **Presenter** | `AddEditItemPresenter.swift` | Sets up the form (blank for add, pre-filled for edit), works out quick dates, turns errors into friendly messages |
| **View** | `View/AddEditItemViewController.swift` + `Common/Views/FormCardRow.swift` | Draws the form and reports what was typed/tapped |
| **Router** | `AddEditItemRouter.swift` | Closes the form. The Builder at the bottom assembles the five parts |
| Link | `PantryListRouter.swift` | Opens the form as a sheet and hands it an `onSaved` callback |

### New ideas in plain words
- **Draft vs real item.** The form produces a *draft*. Only the Interactor can turn it into a real `PantryItem`, after checking the rules. Nothing invalid can reach storage.
- **One form, two jobs.** `existing: PantryItem?` is `nil` for Add and filled for Edit. The same code handles both; only the title, the starting values and "keep the old id" differ.
- **`onSaved` callback.** The form doesn't know about the list. It just says "I saved" through a closure it was handed, and the list refreshes itself. (The list's Router is given a *factory* for building the form, so it never needs the database or clock.)
- **Keyboard layout guide.** The scroll area is pinned to `view.keyboardLayoutGuide.topAnchor`, so the keyboard never covers the Save button.
- **Pop-up menu button.** `UIButton` with a `UIMenu` and `changesSelectionAsPrimaryAction` gives the "Fridge v" picker for free.
- **Test doubles.** A `FailingRepository` that always throws lets us test the "couldn't save" path without breaking anything real.
- **UI tests.** Unit tests check one part alone. `AddEditItemFlowUITests` taps through the real app (add, edit, cancel, validation, swipe-delete). The app is launched with `-uiTesting`, which swaps in a throw-away in-memory store, so tests never touch real data.
- **Removed:** the debug sample-data seeder (it was only a stand-in until this milestone).

### Verified
50 unit tests + 5 UI tests pass, and no crash reports. That includes closing the form (the Presenter being freed), which I had flagged as a risk after the test-host crash.

### Commit messages used
- `feat: add item rules, draft and validation entities`
- `feat: add add/edit item logic (interactor, presenter, router) with tests`
- `feat: add add/edit item form screen`
- `feat: open add/edit form from the pantry list` (the sample-data removal landed inside the first commit)
- `test: add UI tests for add, edit, cancel, validation and delete`
- `docs: add milestone 2 notes to learning log`

### Check your understanding
1. Why does the form create a *draft* instead of saving a `PantryItem` directly?
2. How does the Pantry list know to refresh after the form saves, even though the form has never heard of the Pantry list?
3. What would you change to also forbid names that are only numbers (e.g. "123")? Which VIPER part, and which test would you add?
4. How does one screen handle both "Add" and "Edit"?
5. Why do UI tests launch with `-uiTesting`?

---

## Milestone 3 – Settings and reminders (`feature/settings-reminders`)

The biggest milestone so far. Two features that depend on each other: a Settings screen (the **Me** tab) and expiry reminders that follow those settings.

### What you can do now
- **Me tab:** turn reminders on/off, choose the default ("same day" ... "1 week before"), the reminder time, the date format (match phone / DD/MM/YYYY / MM/DD/YYYY / YYYY-MM-DD, with a live preview), and when items turn red or amber.
- **Per-item reminders:** the Add/Edit form has a "Remind me" row: Default (1 day before), Never, Same day, 1/2/3 days, 1 week.
- **Friendly permission:** the first time you save an item that would get a reminder, we explain why ("Get reminders?") before iOS shows its own pop-up. Only once. If iOS blocks us, Me shows a banner with an "Open Settings" shortcut.
- **Dates on rows:** each pantry row now shows its exact expiry date in your chosen format.

### Your question: two items, different expiry dates, any clash?
No. Every reminder's name is built from the item's **id** (`expiry-<uuid>`), never its name. Two "Milk" items, or renaming an item, can never collide. Editing or deleting an item replaces or removes only its own reminder. (iOS also keeps only 64 pending reminders, so we schedule the soonest 60.)

### The new pieces
| Part | File | Job in plain words |
|---|---|---|
| Entity | `ReminderPreference` | "Use default", "never", or "N days before" for one item (stored as a single number) |
| Entity | `AppSettings` | All the user's preferences in one bundle. Old saved settings still load when we add new fields later |
| Entity | `PlannedReminder`, `NotificationPermission` | A reminder we decided to send; whether iOS allows it |
| Service | `ReminderPlanner` | **The brain.** Pure maths: items + settings + "now" -> list of reminders. No iOS inside, so every rule is unit-tested |
| Service | `NotificationScheduling` | Job description for "put reminders on the phone". Real version (`UserNotificationScheduler`) + pretend version (`StubNotificationScheduler`) |
| Service | `ReminderService` | Says "re-plan and replace everything" whenever something changes. Jobs queue one after another so they never overlap |
| Service | `SettingsStore` | Job description for remembering settings (UserDefaults now, iCloud possible later) |
| Service | `ExpiryDateFormatter` | The one place that writes dates in the user's chosen format |
| **Module** | `Modules/Settings/` | A full VIPER module for the Me tab (View, Presenter, Interactor, Router, Builder) |
| Changed | `Modules/AddEditItem/` | New "Remind me" row and the one-time explainer flow |
| Changed | `Modules/PantryList/` | Reads thresholds from settings, shows exact dates, re-plans reminders after a delete |

### Concepts in plain words
- **Split "deciding" from "doing".** `ReminderPlanner` decides (pure, testable); `UserNotificationScheduler` does (talks to iOS). We test the deciding thoroughly and check the doing separately.
- **Fire-and-forget with a queue.** `reschedule()` returns immediately and does the work in the background. Each job waits for the one before it, so two quick changes can't tangle.
- **Re-plan everything, every time.** Instead of tracking "which reminder to add/remove" we rebuild the whole list and swap it. Simpler, and it can't drift out of sync.
- **A "primer" before the permission pop-up.** iOS lets you ask for notification permission only once. Asking at the right moment, with a reason, gets more "Allow" taps. Our one-time explainer is the "primer".
- **Disabled vs dimmed.** Greyed-out controls must also be `isEnabled = false`, or VoiceOver and automated tests still treat them as usable.
- **Hidden views leave gaps.** Hiding the banner *card* left its margins behind. We hide the whole wrapper row instead.
- **Integration test.** `UserNotificationSchedulerTests` talk to the real iOS notification centre (not a pretend one). iOS only accepts reminders once permission was granted on that simulator, so they skip themselves otherwise.

### Things we tried that didn't work (and why)
- Typing into the browser preview doesn't reach the simulator, so form flows are checked by UI tests instead. Taps do work, which is how we granted notification permission once for the integration tests.
- iOS silently refuses to schedule reminders without permission, even in tests. That is why the integration tests need a one-time "Allow".

### Verified
126 tests pass: 109 unit (planner rules, service, settings, formatter, interactors, presenters), 5 against the real notification centre, 12 UI (explainer allow/decline, "Never", Me tab, date format preview, switching reminders off), and no crash reports.
Not yet verified: seeing a reminder actually appear at its time on a real iPhone. To try it: add an item, set Remind me = "Same day", set the Me tab time to 2 minutes from now, and lock the phone.

### Commit messages used
- `feat: add reminder preference, app settings and planned reminder entities`
- `feat: add settings store, date formatter, reminder planner and scheduling services with tests`
- `feat: add per-item reminder option and reminder explainer to the add/edit form`
- `feat: add settings screen (Me tab) with tests`
- `feat: use settings in the pantry list, show exact dates and keep reminders in sync`
- `test: add UI tests for reminders and settings`
- `docs: add milestone 3 notes`

### Check your understanding
1. Why is each reminder named after the item's id and not its name?
2. Why does `ReminderPlanner` not talk to iOS directly? What does that make easier?
3. Why do we rebuild ALL reminders after every change instead of adding or removing just one?
4. Why do we show our own "Get reminders?" message before iOS's pop-up?
5. If you changed the default from "1 day before" to "3 days before" in Me, which existing reminders change, and which part makes that happen?
6. Where would you add a new setting (say "quiet days")? List the files you would touch, in order.

---

## Testing notes, part 2: why the full run is slow, and what we do about it

Measured on the last full run: 113 unit tests took about **1 second**; 12 UI tests took about **200 seconds**. A full run is about 9 minutes, because each UI test launches the whole app, and every run also builds the app and the tests and starts a simulator copy.

Our routine from now on:
| When | What we run |
|---|---|
| While building a feature | Build, plus only the unit tests for the files we touched (`-only-testing:`) |
| Before merging a milestone | All unit tests, plus the UI tests for screens we changed |
| Big changes / before a release | The full suite |

We also merged two UI tests that repeated the same setup (one app launch saved each).

---

## Milestone 4 – Item photos (`feature/item-photos`)

### What you can do now
Tap the tile next to the name in the Add/Edit form to **take a photo**, **choose one from the library**, or **remove** it. The photo appears in the form and on the pantry row; with no photo you still get the emoji.

### The big idea: a photo is a FILE, and the item remembers only its NAME
Databases are bad at big blobs, so each photo is a small JPEG file in the app's private folder, and `PantryItem.photoFileName` stores just the name (e.g. `3F2A....jpg`). Everything about files hides behind a `PhotoStoring` job description, like the other services.

### The new pieces
| Part | File | Job in plain words |
|---|---|---|
| Entity | `PhotoChange` | What the user did in the form: keep / replace with this picture / remove |
| Service | `JPEGThumbnailer` | Shrinks a big photo to about 600 px, turns sideways phone photos upright, never enlarges small ones |
| Service | `PhotoStoring` + `FileSystemPhotoStore` | Save (returns a fresh file name), load, delete. Also `InMemoryPhotoStore` for tests |
| Common | `PhotoImageCache` | Remembers loaded pictures so scrolling the list doesn't re-read files |
| Changed | Add/Edit module | Photo tile, action sheet, camera + library pickers, and the safe save/cleanup rules |
| Changed | Pantry list | Rows show the photo (or emoji); deleting an item deletes its photo |

### Concepts in plain words
- **Save the new thing first, delete the old thing last.** On save we store the new picture, then save the item, and only then delete the old picture. If anything fails midway, nothing is lost and no stray file is left (there are tests for both failure cases).
- **Nothing is saved until Save is tapped.** Picking a photo only changes the form (kept in the Presenter). Cancel leaves no files behind.
- **A fresh file name every time** (a UUID) means a replaced photo can never show a stale cached copy.
- **Path safety.** A file name is reduced to its last part, so a damaged name like `../../secret` can't escape the Photos folder. There is a test for that.
- **Privacy by design.** The library picker runs outside the app and only hands over what the user taps, so no photo-library permission is needed. Only the camera needs permission, with a plain explanation (`NSCameraUsageDescription` in Info.plist), and a "Camera is off - Open Settings" alert if it was refused.
- **Optional columns upgrade smoothly.** `photoFileName` is optional in the database, so items saved before photos existed still load.
- **Real-world check beat my assumption.** I assumed the simulator has no camera and wrote a test saying "Take photo" is absent. The iOS 26 simulator does report a camera, so the test failed and I fixed the TEST, not the app.

### Verified
151 tests pass, no crash reports. I also tested it for real in the simulator: opened an item, chose "Choose from library", picked a picture in the real iOS photo picker, saved, and saw the photo on the pantry row.
Not yet tested: taking a photo with a real camera on a real iPhone (the simulator can't show a real scene).

### Commit messages used
- `feat: add photo fields to the item entity and storage record`
- `feat: add photo store and JPEG thumbnailer with tests`
- `feat: add photo picking to the add/edit form`
- `feat: show item photos in the pantry list and delete them with the item`
- `test: add UI test for the photo tile and trim overlapping UI tests`
- `docs: add milestone 4 notes`

### Check your understanding
1. Why store a file NAME in the database instead of the photo itself?
2. In what order do we save a replaced photo, and why is that order safe if something fails?
3. What happens to the photo file when you delete an item? Which part of VIPER does it?
4. Why doesn't the library picker need a permission, but the camera does?
5. Why does every saved photo get a brand-new file name?
6. If you wanted to also keep a bigger photo for a future detail screen, which files would you touch?

---

## Milestone 5 – Scan the expiry date (`feature/scan-expiry`)

### What you can do now
Tap **Scan** (or "Scan the date on the pack" in the form). Point the camera at the printed date; a card shows what it found, with a countdown. Tap **Use this date** (or **Use date and keep photo**) and the form fills in. No camera? **Choose a photo of the date**.

### How it works, in three steps
1. **See:** Apple's `DataScannerViewController` (live camera) or `VisionTextRecognizer` (a picked photo) turns a picture into text lines.
2. **Understand:** `ExpiryDateParser` finds the date in those lines. Pure logic, 21 tests, no camera needed.
3. **Confirm:** the Scanner screen (a full VIPER module) shows the result; the user taps to accept. Nothing is filled in without a tap.

### The new pieces
| Part | File | Job in plain words |
|---|---|---|
| Entity | `ScannedExpiryDate`, `ScanResult` | A found date (plus the other day/month reading); what the scanner hands back |
| Service | `ExpiryDateParser` | **The brain.** Reads messy text, picks the expiry date |
| Service | `TextRecognizing` + `VisionTextRecognizer` | "Read the text in this picture" (Apple Vision). `StubTextRecognizer` is the pretend one for UI tests |
| **Module** | `Modules/Scanner/` | View (camera + result card), Presenter, Interactor, Router, Builder |
| Changed | Add/Edit module | "Scan" button, applies the scanned date and optional photo |
| Changed | `RootTabBarController` | Scan tab opens a new item with the scanner (it never "selects" a tab) |

### Concepts in plain words
- **Parsing is mostly rules and edge cases.** Labels (EXP vs MFG), the closest label wins, a label on the line above applies only if that line has no date of its own, month-only dates mean end of month, impossible dates (31/02) and dates outside "a year ago to ten years ahead" are rejected as misreads.
- **Ambiguity is shown, not hidden.** 03/04/26 follows your date-format setting, and the other reading is one tap away. Numbers above 12 can only be the day, so those have no alternative.
- **Debouncing a flickery camera.** A live camera changes its mind every frame, so the Interactor needs the same date twice in a row (`sightingsNeeded`) before reporting. Retry resets it.
- **OCR slips.** Cameras read "O" as "0" and "I" as "1". We fix those only next to digits, so month names like "OCT" stay intact (a test guards this).
- **Fake the slow/real thing in tests, but also test the real thing once.** UI tests use a stub reader; `VisionTextRecognizerTests` draws a fake pack label and runs the REAL Vision reader plus the parser end to end.
- **Choosing a photo is a fallback AND a testing tool.** The simulator has no live camera, so the same screen works from a photo.

### Bugs found and fixed
- **Pantry didn't refresh after saving from the Scan tab.** The form opens as a sheet over the Pantry tab, so the list never got a "will appear" signal. The UI test caught it; the tab bar now tells the list to reload.
- UI test taps: iOS's photo picker reports thumbnails as "not hittable" while animating, so we tap their centre by position. Two screens had a "Cancel" button, so we name the one we mean.
- A test run once hung before starting any test (the simulator was in a bad state). Fix: shut down and reboot the simulator, then rerun.

### Verified
Parser: 21 tests. Real Vision chain: 6 tests. Interactor/presenter: 20 tests. UI: 4 scanner flows (Scan tab to filled form to pantry row, swap day/month, no-date message, cancel).
**Not verified: the live camera.** The simulator can't show a real scene, so please try it on your iPhone: Scan tab, point at a real pack, check the card, and tell me which packs it misreads (dot-matrix dates on cans and bottles are the hardest).

### Commit messages used
- `feat: add scanned date entities and day-first preference`
- `feat: add expiry date parser with tests`
- `feat: add text recognizer (Apple Vision) with tests`
- `feat: add scanner screen (VIPER module) with tests`
- `feat: add scan button to the form and open the scanner from the Scan tab`
- `test: add scanner UI tests`
- `docs: add milestone 5 notes`

### Check your understanding
1. Why does the parser live apart from the camera code? What does that let us do?
2. Why must a date be seen twice before we show it?
3. For "03/04/26", how does the app decide between 3 April and 4 March, and how can the user fix a wrong guess?
4. Why does "MFG 18/05/26 EXP 18/11/26" give 18 Nov, and what if the label is on the line above?
5. Why did saving from the Scan tab not update the list, and how did we fix it?
6. We use a fake text reader in UI tests. Why do we ALSO have a test with the real one?

---

## Fix: the Scan tab stacked two sheets (`fix/scan-tab-opens-scanner-first`)

**What you noticed:** tapping Scan opened the whole "Add item" sheet, then the scanner slid over it. Two sheets at once felt clunky.

**Why it happened:** to save work I reused the form for the Scan tab: open the form, then immediately open the scanner on top. It worked, but it wasn't a good experience. A user who taps "Scan" wants to scan, not see a half-empty form first.

**The fix:** Scan tab -> scanner only. When a date is found and accepted, the scanner closes and a NEW item opens with the date (and the pack photo, if kept) already filled in. Cancelling the scanner leaves nothing behind. The "Scan the date" button inside the form still opens the scanner over the form, which is natural there (you're already filling a form).

**What changed in the code:** the form no longer has a "start with scanner" mode. It takes an optional `prefill` (a `ScanResult`) instead, which is simpler and more general. `RootTabBarController` now chains the two screens: scanner first, then form.

**Lesson:** when you reuse something to save time, ask whether the user would notice the seam. You did. A testing note: unit tests passed before this change too, because they checked that the parts worked, not that the flow felt right. Only using the app caught it.

### Check your understanding
1. Why is "scanner first, then form" a better flow than "form first, then scanner"?
2. What is `prefill`, and why is it more flexible than the old "start with scanner" flag?
3. Our tests passed before the fix. What does that tell you about what tests can and can't catch?

---

## Milestone 6 – Recipes (`feature/recipes`)

### What you can do now
Open the **Recipes** tab: dishes built from your food, with photos, what you'd use and what's missing. Switch **Use up first** / **Best match**. Tap a recipe for ingredients (ticked if you have them), steps, and a link to the original. No internet? Recipes you've already loaded still show, with a note.

### How it works, in plain words
1. **Pick your food:** only items that are still good (expired food is never suggested), soonest-to-expire first.
2. **Translate to the recipe site's words:** "Frozen peas" -> "Peas", "Greek yoghurt" -> "Yogurt" (`IngredientMatcher`). Their database wants exact ingredient names.
3. **Search once per ingredient** (the free service can't search two at once), score recipes higher when they use food that expires sooner, fetch full details for the best 12.
4. **Compare each recipe with your pantry** (`RecipeRanker`) and sort.
5. **Save what we fetched** so it works offline next time.

### The new pieces
| Part | File | Job in plain words |
|---|---|---|
| Entity | `Recipe`, `RecipeMatch` | A recipe; a recipe compared with your pantry (used / missing / score) |
| Service | `IngredientMatcher` | Is "Full cream milk" the "Milk" in a recipe? Simplifies words, handles plurals and spellings |
| Service | `RecipeRanker` | **The brain.** Pure maths; two orderings |
| Service | `RecipeService` + `MealDBRecipeService` | Job description, real TheMealDB version, and a stub for UI tests |
| Service | `RecipeCaching` | Saves fetched recipes on the phone (file), keeps the newest 150 |
| Service | `RemoteImageLoading` | Downloads recipe photos once and remembers them |
| **Module** | `Modules/Recipes/` | The list: Interactor does the fetching/ranking, Presenter the words, View the screen |
| **Module** | `Modules/RecipeDetail/` | The detail screen. **No Interactor**, since it has no logic of its own. VIPER only adds a part when it has a job |

### Concepts in plain words
- **Design around the API you really have.** I tested TheMealDB first: one ingredient per search, `{"meals": null}` (not an empty list) for no results, exact ingredient names, a source link that can be missing. The design (and tests) follow from that.
- **Graceful fallback.** Online fails -> use saved recipes -> else a friendly message. Each case has its own wording.
- **Ignore stale answers.** Every load gets a number; if you start a newer load, older slower ones stop reporting.
- **Reuse what you already have.** Switching the order re-sorts what's loaded, with no new network calls (a test proves it).
- **Safe links.** Only `http`/`https` links are opened, so a strange address in recipe data can't open something else.
- **Test with a fake internet.** A stand-in `URLProtocol` answers requests with canned replies, so tests check the real parsing code without the network.

### Bugs found by really using it (not by tests!)
Running against the real service showed two problems tidy fake data hid:
1. **Duplicates:** two cartons of milk showed "Uses Avocado, Milk, Milk", and counted milk's urgency twice. Fix: treat same-named items as one (the soonest-expiring counts).
2. **Silly top result:** "Use up first" put a recipe missing 12 ingredients first, just because it used lots of expiring food. Fix: `rescueScore` = urgency, reduced about 15% for every ingredient you'd have to buy. Salmon Avocado Salad (missing 3) now beats Chicken Tacos (missing 12).

Test-writing lessons: (a) an XCTest expectation can be fulfilled only once, and fulfilling it twice crashes the test run ("Crash ... signal abrt"). Spies should let go of an expectation after using it. (b) My made-up test foods "Food1, Food2" all became "food" because the matcher ignores digits, so the test was wrong, not the code. (c) `@MainActor` test methods must be `async` in this project.

### Verified
248 unit tests (matcher, ranker, parsing with a fake network, cache, interactor incl. offline paths, presenters) plus 5 UI flows with sample recipes. Also run for real against the live TheMealDB: photos load, rankings look sensible, the detail screen shows ticked ingredients.
Not verified: how the list behaves with a slow or flaky connection on a real phone, and recipes for unusual foods (matching is word-based, so odd names can say "missing" wrongly).

### Commit messages used
- `feat: add recipe entities, ingredient matcher, ranker, TheMealDB service and cache with tests`
- `feat: add recipes screen, recipe detail and image loading (VIPER modules)`
- `test: add recipe interactor, presenter and UI tests`
- `fix: count same-named items once and weigh missing ingredients in use-up-first ranking`
- `docs: add milestone 6 notes`

### Check your understanding
1. Why do we search by ingredient first and fetch details second? What does each call return?
2. Why does the list ranking weigh missing ingredients instead of using expiry alone?
3. What happens, step by step, when you open Recipes with no internet? (Two cases: something saved, nothing saved.)
4. Why does the detail screen have no Interactor?
5. Two cartons of milk: what did the app do wrong at first, and where did we fix it?
6. How do tests check the real TheMealDB parsing code without using the internet?

---

## Milestone 7 – Home tab and "saved from the bin" (`feature/home`)

### What you can do now
The app opens on **Home**: a time-aware greeting, up to three "use soon" tiles, a big **What can I cook?** button, and a **Saved from the bin** counter. In the Pantry, swipe a row left for **Used it**, **Threw away** or **Delete**. In Me you can switch the money estimate off or change the average item value.

### The new idea: remember WHY an item left
Before, deleting an item erased it with no trace. To count food saved we need to know the reason, so each swipe now records a tiny history line (`OutcomeEntry`: name, outcome, date) in a second SwiftData table (`OutcomeRecord`).
| Swipe | Recorded? | Counts as |
|---|---|---|
| Used it | yes, `.used` | food saved |
| Threw away | yes, `.wasted` | not saved (kept for future insights) |
| Delete | no | neither. It's for mistakes, so it never inflates the numbers |

### The new pieces
| Part | File | Job in plain words |
|---|---|---|
| Entity | `ItemOutcome`, `OutcomeEntry` | Why it left; one history line |
| Service | `OutcomeRepository` (+ SwiftData, in-memory) | Another "job description" for storage |
| Service | `MoneyFormatter` | "$3" or "£34" in your own currency |
| **Module** | `Modules/Home/` | Interactor gathers numbers, Presenter writes the friendly sentences, View draws them, Router just switches tabs |
| Changed | Pantry module | Three swipe choices that record history |
| Changed | Settings | "Show money saved" and "Average item value" |
| Changed | `RootTabBarController` | Opens on Home; Home's buttons switch tabs |

### Concepts in plain words
- **Record first, delete second.** If saving the history fails, the item is NOT deleted, so nothing vanishes without a record (a test checks this).
- **A "this month" counter** compares the calendar month and year (October 2026 is not November 2026, and neither is November 2025). Tests cover both.
- **A router can be tiny.** Home's Router only switches tabs: two closures. VIPER doesn't need every part to be big.
- **Safe swipes.** `performsFirstActionWithFullSwipe = false` means a long swipe only reveals the buttons. Accidentally deleting food would feel awful.
- **Database upgrade.** Adding a new table (`OutcomeRecord`) to SwiftData is a light, automatic migration. I checked it on the real app: your existing pantry was still there after the update.
- **Estimates are honest.** The money line says "about", is switchable, and the Settings note explains it is items used x your average value. We don't pretend to know prices.
- **Where you start is a decision.** Real users open on Home; UI tests open on Pantry by default (so older tests still work), or on Home with `-uiTestingStartOnHome`.

### Mistakes and lessons this time
- Two unit-test crashes, both my test-writing, not the app: (1) main-actor test methods must be `async` (a rule we keep hitting; I now check for it every time), and (2) a SwiftData test container must be kept alive for as long as its context is used. If it is thrown away, the test traps.
- I had written a lenient UI assertion (`a || b`). Lenient checks can hide regressions, so I tightened it to the one element that should exist.

### Verified
271 unit tests (Home logic, greeting at every hour boundary, "this month" edge cases, money maths, real SwiftData save/load of every item field including reminder and photo, new settings, swipe outcomes) and 8 UI flows (empty state, tiles, What can I cook, Used it counting, Threw away and Delete not counting, long swipe safety, savings settings). Also checked visually on the real app with real saved data.
Not verified: the greeting text at your real local time zone on a physical phone (the logic is tested at every hour).

### Commit messages used
- `feat: record why items leave the pantry (used, threw away, delete) with history storage`
- `feat: add money-saved options to settings`
- `feat: add the Home tab (VIPER module) and make it the first tab`
- `test: add home, outcome, persistence and settings tests`
- `test: add home and swipe-outcome UI tests`
- `docs: add milestone 7 notes`

### Check your understanding
1. Why does a plain Delete record nothing, while Threw away records `.wasted` but isn't counted as saved?
2. If saving the history fails, what happens to the item, and why is that the right behaviour?
3. What makes "this month" tricky? Name two cases the tests cover.
4. Why does Home's Router need only two closures?
5. How does the app keep a long swipe from deleting food by accident?
6. What does adding the new `OutcomeRecord` table mean for people who already have a pantry saved?

---
