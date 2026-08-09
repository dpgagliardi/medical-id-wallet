# Medical ID Wallet

A Garmin Connect IQ widget that stores your medical ID information (blood type, allergies, conditions, medications, emergency contacts) directly on your watch, viewable at any time without your phone.

**Author:** [SkapaCraft](https://skapacraft.com)

---

## ⚠️ Important: not a medical device

Medical ID Wallet is an **information display tool only**. It is **not a medical device**, is **not certified or approved by any health authority**, and must **not** be used as a substitute for professional medical judgment, diagnosis, or treatment.

- The accuracy of the information shown depends entirely on what you enter: the app does not verify, validate, or cross-check it against any medical record.
- In a real emergency, always follow the instructions of qualified medical personnel and call your local emergency number.
- The author is not responsible for decisions made based on the information displayed by this app. Use it as a convenience, not as a sole source of truth.

## What it shows

- **Blood type**: displayed prominently
- **Name**, computed **age**, date of birth, height, weight
- **National / Health ID**: Codice Fiscale (IT), NHS number (UK), SSN (US), BSN (NL), or any similar identifier
- **Emergency contacts**: name, relationship, phone number (up to 2)
- **Medications, allergies, medical conditions**
- **Organ donor status**
- **Scannable barcode** (QR or Code 39) generated from your National ID or a custom alternate code: scroll down to reveal it; the backlight activates automatically for scanning. The alternate code takes anything you want encoded, such as an insurance number, a race bib, or a link to an online health profile (MedicAlert, OneLife iD and similar services). An optional caption above the code says what it refers to.

All fields are optional. Fill in only what you're comfortable sharing.

## How to configure

Open **Garmin Connect Mobile** → your device → **Widget Settings** → Medical ID Wallet, and fill in the fields you want to appear on the watch.

## Privacy

**100% offline. Zero network requests.** Medical ID Wallet never collects, transmits, or shares any of your information: nothing is sent to SkapaCraft or any third party, and the app never touches the network.

One honest caveat: you enter these fields in Garmin Connect Mobile, so the values are handled by Garmin's own apps and services on their way to the watch, under [Garmin's privacy policy](https://www.garmin.com/en-US/privacy/global/policy/) rather than ours. We can't see that and don't control it. Every field is optional, so leave blank anything you'd rather Garmin not hold.

**Before selling, gifting, or discarding your watch**, remember to reset it to factory settings (or clear the app's settings in Garmin Connect Mobile) to remove your personal and medical information from the device.

## Languages

20 languages supported: the watch automatically uses the system language.
EN · IT · DE · FR · ES · PT · NL · PL · SV · NO · DA · FI · RU · JA · KO · ZH-S · ZH-T · TR · CS · HU

## Navigation

| Input | Action |
|-------|--------|
| DOWN key / swipe up | Scroll down |
| UP key / swipe down | Scroll up |
| MENU / ESC | Back to top |

## Barcode compatibility

- **QR code**: recommended. Renders reliably on all supported devices and scans with any phone camera.
- **Code 39 (linear barcode)**: needs considerably more horizontal space than a watch screen usually offers. The app only draws the bars when they come out wide enough to actually be scanned; otherwise it shows the value as large, readable text rather than a barcode no scanner could decode. With a long value (a 16-character Codice Fiscale, for example) expect the text panel on most devices. Shorter values on larger displays do render as bars.

## Requirements

- Garmin Connect IQ 3.0+
- Compatible with 249 Garmin devices (wrist-worn wearables)

## Build

Needs the [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) and a
developer key.

```bash
SDK="/path/to/connectiq-sdk"
java -jar "${SDK}/bin/monkeybrains.jar" \
  -o bin/medicalidwallet.prg \
  -f monkey.jungle -y your_developer_key.der \
  -d fr955_sim -l 0
```

The checks that run in CI run locally in a second, and need no SDK:

```bash
python3 .github/scripts/check_resources.py
```

## Reporting a security problem

Not in a public issue: use the **Security** tab, then **Report a vulnerability**.
The fields this app holds are medical, so a report stays private until there is
a fix. What counts as one here, and what does not, is in [SECURITY.md](SECURITY.md).

## Contributing

How to report, propose and build is in [CONTRIBUTING.md](CONTRIBUTING.md). The
short version: a new user-facing string means all twenty languages, and CI will
say which ones you missed.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the full history.

## Author

Built by **SkapaCraft** ([skapacraft.com](https://skapacraft.com)).

## Trademarks

Not affiliated with, endorsed by or sponsored by Garmin Ltd. Garmin, Connect IQ
and Garmin Connect are trademarks of Garmin Ltd., named here only to identify
the platform this software runs on.

## Licence

Copyright (C) 2026 SkapaCraft. GPL-3.0-or-later, see [LICENSE](LICENSE).

Any modified version you distribute must stay under GPLv3, and its source must
be made available to whoever receives it. For an application whose promise is
that it never touches the network, a permissive licence would let someone ship
a build that does, under the same name.
