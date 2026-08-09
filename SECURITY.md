# Security policy

## What this application is, and why that shapes the threat model

Medical ID Wallet holds the fields a stranger would need if they found someone
unconscious: blood type, allergies, medications, conditions, a national health
identifier and two emergency contacts. It is not much data, but it is close to
the most sensitive kind a person carries.

Two promises shape everything:

> The application opens no network connections, and it holds nothing beyond
> what the watch owner typed into the settings.

There is a caveat stated in the README rather than hidden: the fields are
entered in Garmin Connect Mobile, so they travel through Garmin's own software
under Garmin's privacy policy on the way to the watch. That path is not ours,
and we cannot make promises about it.

## What counts as a vulnerability here

- **Data leaving the watch.** Any network call, any use of a communications
  API, anything written where another application could read it.
- **Data surviving where it should not.** The settings live in the Connect IQ
  property store, which a factory reset clears. Anything that leaves a copy
  somewhere else belongs here.
- **Showing the wrong person's data**, or showing data the owner cleared.
- **Memory unsafety or a crash from a crafted setting.** Every field is
  untrusted input: the settings page accepts free text up to 512 characters,
  and the barcode encoder runs over it. A value that makes the encoder read out
  of bounds, loop forever or pin the CPU belongs here.
- **A barcode that encodes something other than what is displayed.** The code is
  meant to be scanned by a responder. Encoding a different value than the one
  shown above it would send them to the wrong record, so it is treated as a
  security problem rather than a rendering bug.

Crashing on a malformed setting is a bug, and worth reporting as an issue, but
it is not a vulnerability on its own: bad input should produce a readable
message rather than a stuck widget.

## Out of scope

- Garmin Connect Mobile, Garmin's servers, and the Connect IQ platform itself.
  Report those to Garmin.
- Anyone with physical access to an unlocked watch. The application exists so
  that its data can be read without a phone or a passcode: that is the feature,
  and it is why the README says to factory reset before selling the device.
- The absence of an unlock code on the widget. It is a deliberate choice, not
  an oversight: a responder cannot be asked for a PIN.

## How to report

**Please do not open a public issue for a security problem.** A public report
tells everyone how to exploit it before there is a fix.

Use GitHub's private reporting: the **Security** tab of this repository, then
**Report a vulnerability**. It opens a channel visible only to the maintainer.

Useful in a report, roughly in order of usefulness:

- what an attacker gains, in one sentence
- the steps to reproduce, and the exact field values that trigger it
- the version, from the About line in the settings, and the watch model
- whether it reproduces in the simulator, and on which device target

If a field value that triggers it contains real medical data, replace it with
an equivalent of the same length and shape. This application exists to keep
such values off other people's machines, and that includes the maintainer's.

## What happens then

This is maintained by one person, so no response time is promised that could
not be kept. What is promised instead:

- a report is acknowledged when it is read, even if the answer is that it needs
  time
- a confirmed finding is fixed before anything else, and submitted to the
  Connect IQ Store as soon as it builds
- the fix says what was wrong and since which version, in the changelog
- credit goes to whoever reported it, unless they prefer otherwise

## Supported versions

Only the latest version published on the Connect IQ Store is supported. There
is no back-porting to older ones: update before reporting.
