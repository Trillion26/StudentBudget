# Decisions

Where the brief was ambiguous, or something had to differ from it, this file records the simplest reasonable choice that was made.

## Platform and tooling

- **Minimum iOS is 15.0, not 13.** Flutter 3.47 creates iOS projects with a minimum of iOS 15, and the plugins need it. The brief says to use Flutter's minimum, so the app follows Flutter.
- **Flutter is pinned in `pubspec.yaml` (`environment: flutter: 3.47.6`) and in `.fvmrc`.** GitHub Actions reads the version from `pubspec.yaml`.
- **The bundle ID lives in `ios/Flutter/AppConfig.xcconfig`.** It is the one place to change it.
- **The Windows window opens at phone size (390×844).** Set `STUDENT_BUDGET_WINDOW_SIZE`, for example to `375x667`, to change it. The VS Code launch configurations do this for you.
- **Running as a Windows desktop app needs Visual Studio 2022 Community with "Desktop development with C++".** It is free but not open source. Flutter needs it to build any Windows app. Chrome works without it.
- **In Chrome, SQLite runs in the page and stores its data in IndexedDB.** drift's background worker stopped answering after a few idle seconds in testing, so it isn't used. This only affects development in Chrome; the iPhone and Windows use a normal SQLite file.
- **`intl` is not used.** Rand formatting is a few lines of tested Dart in `lib/logic/money.dart`, so the package was left out.
- **Generated drift code (`*.g.dart`) is committed.** A beginner can then run the app without running build_runner first.

## Data

- **The app covers 2026 to 2035.** Entries can be dated from 1 Jan 2026 to 31 Dec 2035, and Overview, History and the Year view browse that range. The limits are `Validation.firstYear` and `Validation.lastYear` in `lib/logic/validation.dart`. Debt start dates may still be earlier, because a loan can predate the app.

- **Generated row classes are named `Txn` (transactions), `BudgetCategory` (categories) and `AppSettings` (settings).** drift and Flutter already use the names `Transaction` and `Category`. The database tables still match the brief.
- **Goals have a `sortOrder` column, and settings have `lastBackupAt` and `backupReminderHiddenUntil`.** The backup reminder needs them.
- **Transaction dates are stored as `YYYY-MM-DD` text.** This means a date can never shift with time zones.
- **Category names are unique ignoring case, archived ones included.** A unique index on `lower(name)` enforces it.
- **Archived categories don't count in planned income or spending.** Their past spending still shows in Overview, History and the Year view.

## Rules

- **The daily allowance is rounded down to whole rand.** The brief's example "R143 a day" shows whole rand.
- **"Needed per month" is rounded up to whole rand.** "Whole months to the target date" counts calendar months from the current budget month's label to the target date's month, with a minimum of 1.
- **Goal "On track" compares needed per month with the average net saving into the goal.** Net saving is money in minus money out. The average covers the current budget month and the two before it.
- **A goal with a target but no target date shows "No target date".** None of the brief's four labels fits that case.
- **The debt monthly repayment averages the current budget month and the two before it.** Only repayments on or after the debt's start date count.
- **"Repaid this year" uses the calendar year.**
- **"Months since start" counts a month once the same day of the month is reached.**
- **The payoff month is today's month plus the months to pay off.**
- **A latest statement balance replaces the estimate entirely, as the brief says.**
- **History shows each day's spending and a running total of spending so far that month.** For example: "Spent R390 · R1 485 so far".
- **"Took from savings" with a category is not counted against that category's budget.** It was paid from savings.
- **The year view uses the budget months labelled January to December.** For CSV export, "year" means the calendar year of each transaction's date.

## Design and wording

- **The colours come from the app icon** (the piggy bank's deep teal #0E4D6E for text and buttons, the coin's gold #F5C343 for the highlighter and + button, green for income, blue for savings). They replaced the brief's navy and yellow in version 1.1.0. Every text colour has a contrast of at least 4.5:1 in light and dark mode.
- **Income amounts in light mode use a darker green than the bar green.** As text on white the bar green is hard to read.
- **`assets/icon/app_icon.png` is the icon artwork cropped to a full square.** iOS rounds the corners itself. The original artwork, with its transparent margin, is kept as `assets/icon/app_icon_artwork.png`.
- **In dark mode the highlighter mark is drawn at half strength.** The light digits stay readable where they overlap it.
- **Until there is history, the Add sheet shows the biggest-budget categories first.** It shows 12 chips with "All categories" for the rest. The brief's "most-used first" ordering has no data on day one.
- **The amount field accepts spaces and an optional "R".** Values with both a comma and a point, such as "1.250,50", are rejected with a clear message rather than guessed.
- **Thousands separators are non-breaking spaces.** "R1 250" never splits across two lines.
- **The R200 Emergency fund suggestion appears as a tip on the income screen of onboarding.**

## Backups

- **On iPhone, backups and CSV exports go through the share sheet. On Windows and in Chrome they use a save dialog.** Those platforms have no share sheet for files.
- **The integration tests run the backup flow through the same store calls the Settings buttons use.** The iPhone share sheet and file picker are system screens that automated tests can't drive. Check them by hand on a real phone.
- **The Excel export is written by the app itself (`lib/export/xlsx.dart`), using only the `archive` package to zip it.** It works offline on every platform. It holds values, not formulas, so it reads the same in viewers that don't recalculate.
- **The Excel export follows the Year view: budget months labelled January to December.** Budgets count the months that have started, so for the current year a budget to date is compared with spending to date. A past or future year counts all 12 months.
- **Gains and losses are coloured on the cell, not in the number format.** Quick Look on iPhone ignores colours in number formats. Quick Look on the Mac doesn't draw xlsx charts either, so open the file in Excel, Numbers or Google Sheets to see them.
- **CSV files start with a byte-order mark.** Excel then shows emoji and dashes correctly. Text starting with `=`, `+`, `-` or `@` is prefixed with `'` so spreadsheets don't treat it as a formula.
