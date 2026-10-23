# Changelog

All notable changes to Medical ID Wallet are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project uses [semantic versioning](https://semver.org/). The version
here is the one in `manifest.xml`, which is what the Connect IQ Store publishes.

Versions 1.0.1 and 1.0.2 were store iterations made before this repository was
published, so their history starts at the 1.0.2 entry below.

## [Unreleased]

### Added
- Edge cycling computers, for riders who leave the watch at home. The Edge
  520, 520 Plus, 530, 820, 830, 1000, 1030, 1030 Plus, 1030 Bontrager and
  Explore run the widget like the watches do. The Edge 540, 550, 840, 850,
  1040, 1050, Explore 2 and MTB run only device apps, so they get a separate
  device app built from the same code (`manifest-edge.xml`,
  `monkey-edge.jungle`).
- On an Edge, the cue that opens the full profile says to press Enter or tap
  the screen: START there starts the activity timer.

## [1.1.1] - 2026-10-11

### Fixed
- QR codes now work on watches whose widgets get 64 KB of memory
  (Forerunner 55, Instinct 2/2X/2S, Forerunner 245 and others), about a
  quarter of installs according to the Connect IQ Store statistics. They used
  to show the value as plain text with no explanation, because of a fixed
  memory threshold sized for an encoder that stored every module as a
  separate object. The encoder now keeps its data in byte arrays, producing
  identical codes in a fraction of the memory, and checks the memory actually
  free. When a QR still cannot be drawn, the screen now says so.
- The QR is now built over a few timer ticks instead of inside a single
  screen redraw, which on slower watches such as the Forerunner 55 tripped
  the watchdog and closed the app. An empty panel of the final size shows
  for a fraction of a second while it is built.
- On watches with a subscreen (Instinct 2/2S/2X/Crossover/3 Solar/E,
  Descent G1), the barcode was centred with its top-right corner behind the
  subscreen, where the real watch hides part of it under the subscreen's
  frame. The code now stops just below the subscreen and is sized to fit,
  and every scroll stop starts below it. The band beside the subscreen is
  kept empty, so the end of the previous field no longer shows cut in half
  by its frame.

### Changed
- Licence: added a NOTICE file with additional terms under section 7 of the
  GPL version 3. Under 7(b), the author attribution must be preserved in the
  source and in any About, credits or licence screen of a derived app. Under
  7(c), a modified version must not present itself as the original, so it
  cannot use the Medical ID Wallet name or icon. The licence stays
  GPL-3.0-or-later.

## [1.1.0] - 2026-10-11

### Changed
- New launcher icon: an ID card with a heart on a red disc, drawn as bold
  shapes that stay legible down to 26px. It replaces a detailed card
  illustration that turned to mush at watch size and still carried the logo
  of the organization the project used to live under.
- One launcher icon PNG per size the devices actually ask for (17 sizes,
  26x26 to 70x70), generated from SVG masters by `store/icon/build_icons.py`,
  instead of a single 48x48 PNG the compiler rescaled for every device. The
  1-bit Instinct models get a dedicated black and white variant.

- Compact profile layout: each field reads "LABEL: value" on one line
  instead of a label line over a value line, the name fits on one line when
  it can, and the blood type label sits beside its box. Wearers reported
  needing too many DOWN presses to reach the end of a full profile. Phone
  numbers, IDs and dates are never split between words: when one does not fit
  beside its label it moves to its own line, whole.
- Scrolling stops on field boundaries instead of moving a fixed 45% of the
  screen: each DOWN brings the first field not fully shown to the top, so no
  line, number or code is left cut by the screen edge, and the barcode stop
  centres the code on screen. Fewer presses are needed as a result.

### Fixed
- A Code 39 barcode silently left out any character the symbology lacks
  (`_`, `#`, accented letters), so a scanner read back a different value from
  the real ID. Such a value is now shown as text, with a hint to switch to QR.
- The text shown in place of a barcode was drawn on a single line and a long
  override code ran off the panel. It now wraps, and the panel grows to fit.
- The "no data" screen placed its lines at fixed pixel offsets, so they
  overlapped on high-resolution screens and long translations ran under the
  bezel. Lines now wrap and stack by real font height.
- Shortening the profile from the phone while scrolled to the bottom left a
  blank screen until the next scroll; the offset is now pulled back in range.
- The cleanup of the legacy on-device copy of the profile ran on every
  launch and settings change. It now runs once per install.

## [1.0.4] - 2026-09-16

### Removed
- The read-only "About" entry from the settings screen (app version, author,
  website). It cluttered the data-entry flow without giving the wearer
  anything actionable; the same info is already in the Connect IQ Store
  listing and the README.

### Fixed
- Scrolling advanced by a fixed 50px per swipe or button press regardless of
  screen size, so a profile with most fields filled in needed 5-6 swipes to
  reach the bottom on taller screens (reported on a Venu 4 - 45mm). The step
  now scales with the device's screen height instead.

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
