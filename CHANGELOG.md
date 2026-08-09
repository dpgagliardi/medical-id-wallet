# Changelog

All notable changes to Medical ID Wallet are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project uses [semantic versioning](https://semver.org/). The version
here is the one in `manifest.xml`, which is what the Connect IQ Store publishes.

Versions 1.0.1 and 1.0.2 were store iterations made before this repository was
published, so their history starts at the 1.0.2 entry below.

## [Unreleased]

### Changed
- The application classes are named after the app. They still carried
  `SafeRunner`, the name the project had before it became Medical ID Wallet,
  and so did the build command in the README. Renamed to `MedicalId*`, which is
  internal only: the application id, the settings keys and the stored data are
  untouched, and an existing installation upgrades without losing anything.

### Added
- `SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, and issue and pull
  request templates.
- Continuous integration on every push: the resource XML is checked for
  well-formedness, every string id used in the source is checked to exist in
  every one of the 20 languages, and the version in `manifest.xml` is checked
  against the top entry of this file. That last check exists because it is the
  one that failed here, silently, twice.
- Dependabot for the CI actions.

## [1.0.3] - 2026-08-02

### Fixed
- **Unusable on pre-glance devices** such as the Forerunner 235. Two separate
  faults, both below API 3.1.0: `Application.Properties` and
  `Application.Storage` do not exist there, and the resulting symbol resolution
  error bypassed the existing try/catch, so the app crashed while loading
  settings. Scrolling then appeared to quit the app, because on a widget's base
  view the system owns the up and down inputs; the base view now shows a
  localized "press START" cue and hands off to a pushed copy of itself.
- The read-only About line in the settings still advertised a version the
  manifest was not at.
- The README claimed nothing is sent to Garmin. The fields are entered in
  Garmin Connect Mobile and handled by Garmin's own software under Garmin's
  privacy policy, which is not ours to promise.

## [1.0.2] - 2026-07-31

### Added
- **Code label**: an optional caption above the barcode/QR panel, so it is clear whether the code is a race bib, an insurance number or a link to an online health profile. The alternate code field already accepted URLs, and this makes that usable in practice, and the field description now mentions it (all 20 languages).
- Fallback panels now explain themselves. When a value cannot be drawn as a barcode the app says why ("too long for bars, use QR", or "code too long for QR") instead of silently showing plain text, which read as a broken app.

### Fixed
- **Data entered but not shown**: filling in only medications, height/weight or the alternate code left the app on the "no ICE data configured" screen and the data was never displayed.
- **Organ donor status was always English** ("Yes"/"No") on every watch, even though translations existed in all 20 languages.
- **Code 39 geometry**: the wide/narrow bar ratio could render inconsistently, breaking the ratio a scanner decodes on. Code 39 now also refuses to draw bars too thin to be scanned, showing the readable value instead of a barcode that only looks real.
- **Rendering cost**: the barcode was fully redrawn on every frame even while scrolled far off screen (up to ~1100 draw calls per frame for a large QR).
- A failed render could retry itself in an unbounded loop, pinning the CPU and leaving the widget stuck.
- Long unbroken words (medication or allergen names) were clipped at the screen edge instead of wrapping.
- The glance loaded the entire data model, including three 512-character fields, to display only a blood type.
- Impossible dates such as `1990-02-31` were accepted.
- The barcode value in the fallback panel could overflow its panel; it now scales to fit.

## [1.0.0] - 2026-07-26: First public release

**Medical ID Wallet** by SkapaCraft: emergency medical information (ICE) stored directly on your Garmin watch.

### Features
- ICE info screen: blood type, name, age/date of birth, height/weight, national ID, emergency contacts (name + relationship + phone), medications, allergies, medical conditions, organ donor status
- Scannable barcode (QR or Code 39) generated from your National ID or a custom alternate code, with automatic backlight while visible
- The alternate code accepts anything you want encoded, such as an insurance number, a race bib, or a link to an online health profile (e.g. MedicAlert), with an optional caption shown above the code so it is clear what it refers to
- Fully scrollable single-screen layout, high-contrast display for fast reading in an emergency
- 20 languages, auto-selected from the watch's system language: EN, IT, DE, FR, ES, PT, NL, PL, SV, NO, DA, FI, RU, JA, KO, ZH-S, ZH-T, TR, CS, HU
- All fields optional and configured via Garmin Connect Mobile: nothing is required to install and use the app
- 100% offline: no network requests, no data collection, no analytics: see [README](README.md#privacy) for details

### Compatibility
- QR code: renders reliably on all supported devices: **recommended format**
- Code 39 barcode: needs a lot of horizontal space, so it only renders when the bars come out wide enough to actually be scanned. With a long value (e.g. a 16-character Codice Fiscale) that is not achievable on most watch screens, and the app shows the value as large readable text instead of an unscannable barcode. Shorter values on larger displays do render as bars.
