# Security Policy

## These labs are intentionally vulnerable — by design

Road to Root ships **deliberately misconfigured** systems so people can learn
privilege escalation by doing it. The vulnerabilities are the whole point.

So, to be clear:

- **"The target box is exploitable" is not a security bug.** Please don't report
  that `labuser1` can get root — that's the lab working as intended.
- The intended use is **local, in disposable containers, on hardware you own.**
  Do **not** expose these containers to the internet or any network you don't
  control, and never use the techniques here against systems you aren't
  explicitly authorized to test. Unauthorized access to computers is a crime.

## What *is* worth reporting

Please do report, privately, anything that is unintentionally dangerous to
someone **running or building this repo**, for example:

- A supply-chain problem in the build or CI (a malicious/compromised dependency,
  action, or download URL).
- A lab that can affect the **host** rather than staying inside its container,
  or instructions that would.
- Leaked real secrets/credentials accidentally committed to the repo.
- A flaw in the repo's own tooling or docs that could harm a user who follows them.

## How to report

Please use **GitHub's private vulnerability reporting**:
_Security → Report a vulnerability_ on this repository
(<https://github.com/Adw0rm-sec/road-to-root/security/advisories/new>).

If that's unavailable, open a normal issue **without** sensitive details and ask
for a private channel. We'll respond as quickly as we reasonably can.

## Supported versions

This is an educational project; only the latest `main` is maintained.
