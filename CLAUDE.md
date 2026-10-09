# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Student Budget is a Flutter app (iPhone first) for a South African student to plan and track a monthly budget in rand. It is offline only: no accounts, no network requests, no analytics. All data lives in a local SQLite file. The README is written for a beginner developer on Windows; `DECISIONS.md` records every rule where the original brief was ambiguous. Read `DECISIONS.md` before changing a budget rule, and add to it when you make a new choice.

## Commands

Flutter is pinned to **3.47.6** (`pubspec.yaml` `environment.flutter` and `.fvmrc`; GitHub Actions reads the pubspec line).

```sh
flutter pub get
flutter analyze                                   # must report "No issues found!"
flutter test                                      # unit + widget tests
flutter test test/logic/budget_month_test.dart    # one file
flutter test test/logic/budget_month_test.dart --plain-name "start day"   # tests whose name contains the text
flutter test integration_test -d <device>         # add-expense and backup flows (CI runs them on an iPhone simulator)
dart format -l 120 <paths>                        # line length is 120 (.vscode/settings.json)
```

- **Layout check:** `flutter test tool/screenshots/screenshots_test.dart --dart-define=OUT=build/screenshots` renders every main screen at iPhone SE, 390 wide, Pro Max, dark mode and double text size. It fails on any overflow. Emoji and icons render as boxes in these PNGs.
- **Sample Excel export:** `flutter test test/export/year_report_test.dart --dart-define=OUT=build/student-budget-2026.xlsx`.
- **After editing `lib/data/tables.dart`:** run `dart run build_runner build`. The generated `*.g.dart` files are committed. Raise `schemaVersion` in `lib/data/database.dart` and add a migration so phones keep their data.
- **App icon:** after replacing `assets/icon/app_icon.png`, run `dart run flutter_launcher_icons`.
- **Unsigned .ipa** (same steps as `.github/workflows/ios.yml`; needs Xcode, no CocoaPods because plugins use Swift Package Manager):
  ```sh
  flutter build ios --release --no-codesign
  rm -rf Payload && mkdir Payload && cp -R build/ios/iphoneos/Runner.app Payload/ && zip -qry StudentBudget.ipa Payload && rm -rf Payload
  ```
  Friends sign it themselves with SideStore or AltStore (`INSTALL-ON-IPHONE.md`). A version tag `v*` makes CI publish a GitHub Release with the `.ipa`.
- **Releasing:** bump the version in both `pubspec.yaml` and `lib/app_info.dart` (`test/app_info_test.dart` checks they match).

## Architecture

Three layers, with imports only going down:

1. **`lib/logic/`: pure Dart rules, no Flutter or drift imports.** `BudgetCalculator` (month figures, money left, daily allowance, goal progress, year summary), `DebtCalculator`, `BudgetMonth`, `money.dart` (rand formatting and parsing), `dates.dart`, `validation.dart`. The calculators take `TxnFacts` (`models.dart`) rather than database rows, so the tests pass fixed dates and plain values. New budget rules go here, with a test in `test/logic/`.
2. **`lib/data/`: drift database and state.**
   - `tables.dart` defines the schema. Row classes are renamed to avoid clashes with Flutter and drift: `Txn`, `BudgetCategory`, `CategoryGroup`, `SavingsGoal`, `Debt`, `AppSettings`.
   - `BudgetStore` (a `ChangeNotifier`) performs every write, then calls `reload()`. That re-reads all tables into a new immutable **`AppData`** snapshot and notifies listeners. Students have at most a few thousand rows, so everything is held in memory and recalculated; there are no per-screen queries.
   - `AppData` holds the lookups (`categoryById`, `groupById`), the derived lists (`facts`, `spendingGroups`, planned income and spending) and thin wrappers that feed `logic/` calculators (`summary`, `goalProgress`, `debtEstimate`).
   - `backup.dart` handles the JSON backup (with `backupSchemaVersion`; keep reading old versions) and the CSV export. `seed.dart` holds the starter budget.
   - `connection/` uses a conditional import: native SQLite file, or an in-page SQLite in IndexedDB for Chrome.
3. **`lib/features/<screen>/` and `lib/design/`: Cupertino UI.** Screens get the store with `StoreScope.of(context)` (rebuilds on change) or `StoreScope.read(context)` (in callbacks). `SelectedMonthScope` shares the month shown on Overview and History. Use the shared widgets in `design/widgets.dart` (`PageScaffold`, `ListRow`, `SectionTitle`, buttons, `MonthSwitcher`) and the colour tokens from `AppColors.of(context)`, never hard-coded colours. Every screen must work in light and dark mode at 375×667 and at double text size.

`lib/export/` sits beside `data/`. `xlsx.dart` is a small hand-written .xlsx writer: shared strings, styles, merged cells, and DrawingML bar, doughnut and line charts, zipped with `archive`. `year_report.dart` builds the yearly workbook (Dashboard, Months, Transactions, Goals & debts) from `AppData`. It writes values with cached chart data, not formulas, because Quick Look and other viewers don't recalculate. Colour gains and losses on the cell; colours in number formats (e.g. `[Color10]`) are ignored by Quick Look.

### Domain rules that span files

- **Money is always whole cents in an `int`.** Format only through `formatRand`; it uses a non-breaking space as the thousands separator.
- **Dates are calendar days** stored as `YYYY-MM-DD` text and handled as UTC midnight (`dateOnly`, `day()` in `dates.dart`). Never use local `DateTime` arithmetic for days.
- **Budget months:** `BudgetMonth(year, month, startDay)` labelled "October 2026" runs from the start day of October up to the day before the start day of November. The start day (1–28) is a setting, so always find the month for a date with `data.monthOf(date)` / `BudgetMonth.containing`, not `date.month`. The Year view and the Excel export use the budget months labelled January–December; the CSV export uses calendar years.
- **Transaction kinds** (`TxnKind`): `income` and `expense` need a category; `toSavings` and `fromSavings` need a goal. `fromSavings` may carry a category but is **not** counted as spending or against that category's budget.
- **Year range:** the app covers `Validation.firstYear`–`Validation.lastYear` (2026–2035). Date pickers, `MonthSwitcher` limits, the Year view, `SelectedMonth.resolve` and export year pickers all read these constants.
- **Archived categories** don't count in planned income or spending, but their past spending still appears in History, Overview and the Year view.
- Category names are unique ignoring case, including archived ones; this is enforced in code and by a unique index on `lower(name)`.

### Testing

- `test/support/test_store.dart` gives a seeded in-memory `BudgetStore` with a fixed clock: Wednesday 7 October 2026, 10:00.
- `test/support/app_harness.dart` pumps the whole app for widget tests.
- Inject time through the store's `clock` / `store.today()`; never call `DateTime.now()` in logic.
- The iPhone share sheet and file picker can't be driven by tests. Exports and backups are tested through the store methods (`exportBackupJson`, `exportCsv`, `exportExcel`, `restore`) that the Settings buttons call.

## Constraints

- Add no package that makes network requests or collects data. `ios/Runner/PrivacyInfo.xcprivacy` declares that nothing is collected.
- Files leave the phone only through `exportFile` in `features/settings/backup_actions.dart`: the share sheet on iOS, a save dialog on Windows and in Chrome.
- User-facing text is short, plain and second person ("Pick a date up to 31 Dec 2035"), with amounts in rand.
