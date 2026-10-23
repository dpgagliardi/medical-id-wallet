# Medical ID Wallet

A Garmin Connect IQ widget that stores your medical ID information (blood type, allergies, conditions, medications, emergency contacts) directly on your watch or Edge cycling computer, viewable at any time without your phone.

**Author:** [dpgagliardi](https://github.com/dpgagliardi)

**[Get it on the Connect IQ Store](https://apps.garmin.com/apps/e72b255d-4447-4834-8b2f-5f7e2b431387)** · **[Privacy policy](PRIVACY.md)** · **[Changelog](CHANGELOG.md)**

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

Open **Garmin Connect Mobile** → your device → **Widget Settings** (or **App Settings** on Edge 540, 840, 1040 and later) → Medical ID Wallet, and fill in the fields you want to appear on the device.

## Privacy

**100% offline. Zero network requests.** Medical ID Wallet never collects, transmits, or shares any of your information: nothing is sent to me or to any third party, and the app never touches the network.

One honest caveat: you enter these fields in Garmin Connect Mobile, so the values are handled by Garmin's own apps and services on their way to the watch, under [Garmin's privacy policy](https://www.garmin.com/en-US/privacy/global/policy/) rather than ours. We can't see that and don't control it. Every field is optional, so leave blank anything you'd rather Garmin not hold.

Full [privacy policy](PRIVACY.md).

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

- **QR code**: recommended. Scans with any phone camera, and renders on every supported device except a few models from 2015 to 2017 (Forerunner 230/235/630/735XT/920XT, fenix 3, D2 Bravo and Charlie, vivoactive and vivoactive HR, epix, Approach S60), whose firmware lacks what the encoder needs; there the app says so and Code 39 is the alternative.
- **Code 39 (linear barcode)**: needs considerably more horizontal space than a watch screen usually offers. The app only draws the bars when they come out wide enough to actually be scanned; otherwise it shows the value as large, readable text rather than a barcode no scanner could decode. With a long value (a 16-character Codice Fiscale, for example) expect the text panel on most devices. Shorter values on larger displays do render as bars.

## Requirements

- Garmin Connect IQ 3.0+
- Compatible with 136 Garmin watches and 10 Edge cycling computers (Edge 520, 520 Plus, 530, 820, 830, 1000, 1030, 1030 Plus, 1030 Bontrager, Explore) as a widget
- Edge 540, 550, 840, 850, 1040, 1050, Explore 2 and MTB run only device apps, not widgets, so they get a separate device app built from the same code

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

The device app for the newer Edge computers builds from the same sources with
its own jungle and manifest:

```bash
java -jar "${SDK}/bin/monkeybrains.jar" \
  -o bin/edge/medicalidwallet.prg \
  -f monkey-edge.jungle -y your_developer_key.der \
  -d edge1040 -l 0
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

Built and maintained by [dpgagliardi](https://github.com/dpgagliardi) as a personal
project, in spare time.

- **Bugs and suggestions:** open an [issue](https://github.com/dpgagliardi/medical-id-wallet/issues).
- **Security problems:** privately, as described in [Reporting a security problem](#reporting-a-security-problem).
- **Anything else:** dpgagliardi.dev@gmail.com

## Trademarks

Not affiliated with, endorsed by or sponsored by Garmin Ltd. Garmin, Connect IQ
and Garmin Connect are trademarks of Garmin Ltd., named here only to identify
the platform this software runs on.

## Licence

Copyright (C) 2026 Daniele Gagliardi. GPL-3.0-or-later, see [LICENSE](LICENSE).

[NOTICE](NOTICE) adds two terms the GPL allows in section 7. Under 7(b), the
author attribution stays: copies of the source keep NOTICE and the file
headers, and a derived app that shows an About, credits or licence screen
credits the original project there. Under 7(c), a modified version must not
pass itself off as the original: it cannot be called Medical ID Wallet, in the
app or in a store listing, nor use this project's icon.

Any modified version you distribute must stay under GPLv3, and its source must
be made available to whoever receives it. For an application whose promise is
that it never touches the network, a permissive licence would let someone ship
a build that does, under the same name.
