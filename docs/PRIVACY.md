# Public repository privacy review

Reviewed before publication on 2026-09-19.

## Scope and findings

- Reviewed every commit and file in the original two-commit history, including author/committer metadata.
- Found personal author metadata and a hard-coded local simulator identifier; neither is retained in the public history.
- Rebuilt public history with the account's GitHub noreply identity and automatic simulator selection.
- Changed personal bundle identifier prefixes to generic `com.example` values.
- Searched history and the prior GitHub Actions log for credentials, private keys, personal contact details, local home paths, signing identities, and device identifiers. No credentials or signing secrets were found by these checks.
- The only tracked image is the documented upstream bus test fixture. It contains no EXIF tags. Personal camera frames and screenshots are not tracked.
- Reviewed the prior CI result bundle: no screenshot attachments were exported. Original CI records and original history remain in a private backup repository; they are not transferred into this public repository.
- Build outputs, raw diagnostics, test results, camera screenshots, environment files, and common signing/private-key files are ignored by Git.

The GitHub account name, GitHub noreply address, project source, dependency versions, and aggregate device/model performance results are intentionally public. This review describes the checks performed; it is not a guarantee against every possible form of sensitive data.

## Verification after sanitization

The simulator test suite passed: 5 tests passed, 1 live-camera test skipped because no local bridge was running, 0 failures. Standard image inference ran against all three actual Core ML models. Existing phone installations were not modified.

## Future contributions

Use a GitHub noreply commit email. Review `git diff --cached` and the changed file list before pushing. Never force-add ignored camera captures, provisioning profiles, private keys, raw device logs, or `.xcresult` bundles. Keep live-camera tests on a local machine and public CI on hosted runners with test fixtures.
