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
