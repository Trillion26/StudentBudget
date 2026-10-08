# Student Budget

An iPhone app for a South African student to plan and track a monthly budget in rand. Everything stays on the phone. There are no accounts, no internet, no ads and no tracking.

This README is for the developer. Friends who just want to install the app should read [INSTALL-ON-IPHONE.md](INSTALL-ON-IPHONE.md).

You develop on **Windows** in **Visual Studio Code**. The iPhone app is built in the cloud by **GitHub Actions** on a free Mac, so you never need a Mac.

---

## 1. Set up your Windows computer (once)

Everything here is free.

1. **Install Git.** Download it from <https://git-scm.com/download/win> and keep the default options.
2. **Install Visual Studio Code** from <https://code.visualstudio.com>.
3. **Install the Flutter SDK, version 3.47.6.** This project is pinned to that version.
   - Open <https://docs.flutter.dev/release/archive>, choose **Windows**, and download **3.47.6 (stable)**.
   - Unzip it so you end up with `C:\src\flutter\bin\flutter.bat`. Avoid `Program Files` and paths with spaces.
   - Add `C:\src\flutter\bin` to your PATH: Start › type "environment variables" › **Edit environment variables for your account** › **Path** › **Edit** › **New** › `C:\src\flutter\bin` › OK.
4. **Turn on Windows Developer Mode.** Flutter plugins need it on Windows: Settings › System › For developers › **Developer Mode** › On.
5. **Install Google Chrome**, if you don't have it. It is the quickest way to run the app.
6. **Optional: to run the app as a Windows app**, install **Visual Studio 2022 Community** (free) from <https://visualstudio.microsoft.com/vs/community/>. In the installer, tick **Desktop development with C++**. This is different from VS Code. Without it you can still use Chrome.
7. Open a new terminal (Start › "Terminal") and run:

   ```powershell
   flutter --version     # should say 3.47.6
   flutter doctor
   ```

   `flutter doctor` lists what is missing. You can ignore the Android and Xcode lines. The Visual Studio line only matters if you want the Windows app.

## 2. Get the code and open it

```powershell
git clone https://github.com/<your-github-name>/StudentBudget.git
cd StudentBudget
code .
```

When VS Code asks, install the **recommended extensions** (Dart and Flutter). It runs `flutter pub get` for you. You can also run it yourself in the VS Code terminal (Terminal › New Terminal).

## 3. Run the app

Open **Run and Debug** in the left bar (or press Ctrl+Shift+D), pick a configuration, then press **F5**:

| Configuration | What you get |
| --- | --- |
| Chrome – phone-sized window | The app in a 390×844 Chrome window. Works without Visual Studio. |
| Windows – iPhone 15 size (390×844) | The app as a Windows window the size of an iPhone. |
| Windows – iPhone SE size (375×667) | The smallest supported iPhone. |
| Windows – Pro Max size (430×932) | The largest supported iPhone. |

While the app runs, save a file (Ctrl+S) to see your change straight away (hot reload).

To test **dark mode**, switch Windows to dark: Settings › Personalisation › Colours › Dark. To test **large text**, set Settings › Accessibility › Text size to 200%. Check that nothing gets cut off at 375×667, in light and in dark mode.

Data you enter on Windows or in Chrome stays on that computer. It is separate from any iPhone.

## 4. Run the tests

- In VS Code, open the **Testing** panel (the flask icon) and press the play button. Or run:

  ```powershell
  flutter test
  ```

- The tests cover every budget rule with fixed dates: budget-month boundaries, the daily allowance, goals, debts and rand formatting. They also cover seed data, the backup round trip, rejection of damaged backups, and the main screens.
- The integration tests in `integration_test/` cover adding an expense and backup with restore. GitHub Actions runs them on an iPhone simulator. On Windows you can run them with `flutter test integration_test -d windows`.
- Optional: render every screen to PNG files and check for layouts that overflow at iPhone SE size, Pro Max size, in dark mode and at double text size:

  ```powershell
  flutter test tool/screenshots/screenshots_test.dart --dart-define=OUT=build/screenshots
  ```

  Emoji and icons show as boxes in these images, because the test runner has no emoji or icon fonts.

## 5. Build the iPhone app (in the cloud)

Every push to `main` starts the **iPhone build** workflow (`.github/workflows/ios.yml`) on a free macOS machine at GitHub. It runs these steps:

1. Install Flutter (the version in `pubspec.yaml`).
2. Run `flutter test`. It stops here if any test fails.
3. Run the integration tests on an iPhone simulator.
4. Run `flutter build ios --release --no-codesign`.
5. Package `build/ios/iphoneos/Runner.app` into `Payload/` and zip it as **`StudentBudget.ipa`**.
6. Upload the `.ipa` as a workflow artifact. On a version tag, it also attaches the `.ipa` to a GitHub Release.

To get the `.ipa` from a normal push, open your repository on github.com › **Actions** › the latest **iPhone build** run › **Artifacts** › `StudentBudget-ipa`. It downloads as a zip with the `.ipa` inside.

**Cost:** GitHub's macOS machines are free for **public** repositories. **Private** repositories get a limited free allowance each month, and macOS minutes count 10 times. One build takes roughly 10–20 minutes.

The `.ipa` is **unsigned**. Each person who installs it signs it with their own free Apple ID using SideStore or AltStore (see [INSTALL-ON-IPHONE.md](INSTALL-ON-IPHONE.md)).

## 6. Publish a release and send it to a friend

1. Change the version in **two places**:
   - `pubspec.yaml`, for example `version: 1.0.1+2` (the number after `+` must go up every time)
   - `lib/app_info.dart`, for example `const String appVersion = '1.0.1';` (a test checks that the two match)
2. Commit and push:

   ```powershell
   git commit -am "Version 1.0.1"
   git push
   ```

3. Tag the version and push the tag:

   ```powershell
   git tag v1.0.1
   git push origin v1.0.1
   ```

4. Wait for the **iPhone build** run for the tag to go green (Actions tab). It creates a **Release** with `StudentBudget.ipa` attached.
5. Send your friend this link, together with [INSTALL-ON-IPHONE.md](INSTALL-ON-IPHONE.md):

   ```text
   https://github.com/<your-github-name>/StudentBudget/releases/latest
   ```

   Friends can only open release links in a **public** repository. If yours is private, make it public (Settings › General › Danger Zone › Change visibility), or download the `.ipa` and send the file another way.

## 7. Project layout

```text
lib/
  main.dart, app.dart      start-up, theme, onboarding vs. tabs
  logic/                   plain Dart rules (no Flutter): BudgetCalculator, DebtCalculator,
                           BudgetMonth, rand formatting and parsing, validation
  data/                    drift database and tables, seed data, BudgetStore (all changes),
                           backup JSON encoder/decoder, CSV export
  features/                one folder per screen: overview, add, history, budget, goals,
                           debts, year, settings, onboarding, lock, home (tab bar)
  design/                  colours (AppColors), Nunito text styles, highlighter, shared widgets
assets/fonts/              Nunito (bundled so it works offline)
assets/icon/app_icon.png   1024×1024 app icon
ios/Runner/                Info.plist, PrivacyInfo.xcprivacy
ios/Flutter/AppConfig.xcconfig   the bundle ID, in one place
test/                      unit and widget tests
integration_test/          add-expense and backup-restore flows
tool/screenshots/          optional screenshot and layout check
.github/workflows/         ios.yml (build) and testflight.yml (optional)
DECISIONS.md               choices made where the brief was ambiguous
```

### Common changes

- **App icon:** replace `assets/icon/app_icon.png`, then run `dart run flutter_launcher_icons`.
- **Bundle ID:** edit `ios/Flutter/AppConfig.xcconfig`. Sideloading tools may change it for each person anyway, and the app doesn't depend on it.
- **Database tables:** after editing `lib/data/tables.dart`, run `dart run build_runner build`. Raise `schemaVersion` in `lib/data/database.dart` and add a migration, so phones keep their data.
- **Backup format:** if the format changes, raise `backupSchemaVersion` in `lib/data/backup.dart` and keep reading the old version.
- **Starter categories:** edit `lib/data/seed.dart`.

## 8. Privacy

- The app makes no network requests and contains no analytics or ads. No package that does is included.
- `ios/Runner/PrivacyInfo.xcprivacy` declares that no data is collected and nothing is tracked.
- Data stays in an SQLite file on the phone, unless the student saves a backup or exports a CSV themselves.
- App lock (optional) uses Face ID, Touch ID or the passcode through `local_auth`. It locks on launch and after 2 minutes in the background. While the app is in the app switcher, its screen is covered.

## 9. Optional: TestFlight (paid Apple Developer account)

The free route is sideloading. If you later join the **Apple Developer Program** (US$99 a year), friends can install through Apple's **TestFlight** app instead. A TestFlight build lasts 90 days and needs no weekly refresh.

`.github/workflows/testflight.yml` is off by default. It only runs when you start it by hand from the Actions tab. To set it up:

1. In your Apple Developer account, create an app ID with your bundle ID. Then create an **Apple Distribution** certificate and an **App Store** provisioning profile for it.
2. In App Store Connect, create the app. Then create an **API key** under Users and Access › Integrations, with the App Manager role.
3. In GitHub: your repository › Settings › Secrets and variables › Actions › **New repository secret**. Add these secrets:

   | Secret | Value |
   | --- | --- |
   | `IOS_BUNDLE_ID` | your bundle ID, e.g. `za.co.yourname.studentbudget` |
   | `APPLE_TEAM_ID` | your 10-character team ID |
   | `IOS_PROFILE_NAME` | the provisioning profile's name |
   | `IOS_DIST_CERT_P12_BASE64` | the certificate exported as `.p12`, base64-encoded |
   | `IOS_P12_PASSWORD` | the `.p12` password |
   | `IOS_PROFILE_BASE64` | the `.mobileprovision` file, base64-encoded |
   | `ASC_KEY_ID` | the API key ID |
   | `ASC_ISSUER_ID` | the issuer ID |
   | `ASC_KEY_P8_BASE64` | the `.p8` key file, base64-encoded |

   To base64-encode a file on Windows:

   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("dist.p12")) | Set-Clipboard
   ```

4. Go to Actions › **TestFlight upload (optional)** › **Run workflow**. It uses fastlane (`ios/fastlane/Fastfile`) to sign and upload the build. Then invite friends in App Store Connect › TestFlight.

## 10. Packages and licences

Everything is free and open source, apart from Apple's platform and your free GitHub account.

| Package | What it's for | Licence |
| --- | --- | --- |
| Flutter and Dart SDK | the framework | BSD-3-Clause |
| drift 2.35 | SQLite database layer | MIT |
| drift_flutter 0.3 | opens the database file on the phone | MIT |
| sqlite3 3.5 | SQLite itself (bundled) | MIT (SQLite is public domain) |
| path_provider 2.1 | temporary folder for backup files | BSD-3-Clause |
| fl_chart 1.2 | year chart | MIT |
| local_auth 3.0 | Face ID / passcode app lock | BSD-3-Clause |
| share_plus 13.3 | iPhone share sheet for backups | BSD-3-Clause |
| file_picker 13.1 | picking a backup file to restore; save dialog on Windows | MIT |
| uuid 4.6 | record IDs | MIT |
| cupertino_icons 1.0 | iOS-style icons | MIT |
| *Development only:* drift_dev, build_runner | generating database code | MIT, BSD-3-Clause |
| *Development only:* flutter_launcher_icons | generating the app icon | MIT |
| *Development only:* flutter_lints, flutter_test, integration_test | code checks and tests | BSD-3-Clause |
| Nunito font | all text | SIL Open Font Licence 1.1 (`assets/fonts/OFL.txt`) |
| subosito/flutter-action, softprops/action-gh-release | GitHub Actions steps | MIT |
| fastlane (optional TestFlight only) | signing and upload | MIT |

One transitive package, `dbus`, is MPL-2.0. Only the Linux versions of two plugins use it. It is not built into the iPhone or Windows app.

## 11. Troubleshooting

| Problem | Fix |
| --- | --- |
| `flutter` is not recognised | PATH is missing `C:\src\flutter\bin`. Open a **new** terminal after changing PATH. |
| "Building with plugins requires symlink support" | Turn on Windows Developer Mode (step 1.4). |
| No Windows device in VS Code | Install Visual Studio 2022 Community with "Desktop development with C++", or use Chrome. |
| The GitHub build fails at "Run unit and widget tests" | Run `flutter test` on your computer, fix the failing test, then push again. |
| The Release has no `.ipa` | Releases are only made for tags starting with `v` (e.g. `v1.0.1`). Check that the tag's run went green. |
