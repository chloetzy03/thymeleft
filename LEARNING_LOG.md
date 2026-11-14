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
