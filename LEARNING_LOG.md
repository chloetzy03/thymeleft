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

