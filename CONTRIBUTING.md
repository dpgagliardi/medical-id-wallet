# Contributing to Medical ID Wallet

This is maintained by one person, so the most useful contribution is usually a
precise report rather than a large patch. Everything below exists to make a
change reviewable, not to add ceremony.

## Before anything else

A security problem does not belong in a public issue. Use the **Security** tab,
then **Report a vulnerability**. What counts as one here is in
[SECURITY.md](SECURITY.md).

## Reporting a bug

Open an issue with the bug template. What makes a report actionable:

- the exact steps, from a clean state, and what you expected instead
- the version, and the platform it ran on
- a file or a screenshot when the trigger is one specific input

If the input holds personal data, describe how to build an equivalent one
rather than attaching it.

## Suggesting a feature

Open an issue with the feature template and describe the problem before the
solution. A feature that does not pull its weight does not ship: that is the
project's standard, not a rejection of the idea.

## Pull requests

Open an issue first for anything beyond a typo or a one-line fix, so the design
is agreed before the work happens.

Once that is settled:

1. Branch from `main`.
2. Keep the change to one concern. Two unrelated fixes are two pull requests.
3. Add a `CHANGELOG.md` entry, and bump the version where the project keeps it.
4. Verify it, and say in the pull request how you did.

## Building and checking locally

Needs the [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) and a
developer key.

```bash
SDK="/path/to/connectiq-sdk"
java -jar "${SDK}/bin/monkeybrains.jar" \
  -o bin/medicalidwallet.prg \
  -f monkey.jungle -y your_developer_key.der \
  -d fr955_sim -l 0
```

Build for more than one device before opening a pull request. The faults that
get through are the device-specific ones: an older target such as `fr235` sits
below API 3.1.0 and does not have `Application.Properties` at all.

CI cannot compile, because the SDK needs Garmin's licence accepted
interactively. What it does check runs locally too, and takes a second:

```bash
python3 .github/scripts/check_resources.py
```

That parses every resource XML, verifies each of the 20 translations defines
exactly the same string ids as the default language, and verifies the version
in `manifest.xml` matches the newest released entry in `CHANGELOG.md`.

A new user-facing string means adding it to **all twenty**
`resources-*/strings/strings.xml` files, not only the English one. The check
will tell you which are missing, but a machine translation nobody read is worse
than an English fallback: say so in the pull request if that is what you did.

## House rules

- **English only**, in code comments, commit messages and user-facing strings.
- **Commit messages** say what changed and why. The subject line is imperative
  and under 72 characters, the body wraps at 72 and explains the reasoning that
  is not obvious from the diff.
- **No generated or vendored files** in a commit unless the project already
  tracks them.
- **No credentials, keys or personal data**, including in test fixtures.

## Licence

By contributing you agree that your work is distributed under the licence in
[LICENSE](LICENSE).
