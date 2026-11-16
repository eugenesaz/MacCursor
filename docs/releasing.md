# Releasing

Releases are built by `.github/workflows/release.yml` when a `vX.Y.Z` tag is pushed. It checks
that `CHANGELOG.md` has notes for that version, runs `check.sh`, signs the app with the
**MacCursor Release** identity, zips it, writes the signed update feed (`appcast.xml`), and
publishes a GitHub release with the zip, its checksum and the feed. If any step fails, nothing
is published.

Installed copies of MacCursor read
`https://github.com/eugenesaz/MacCursor/releases/latest/download/appcast.xml` once a day (or
right away with **Check for Updates…**), so a new release reaches everyone automatically.

## Secrets (made once, 2026-11-16)

| Secret | What | Made by |
|---|---|---|
| `RELEASE_IDENTITY_P12_BASE64`, `RELEASE_IDENTITY_PASSWORD` | Code-signing certificate "MacCursor Release" (self-signed, valid until 2036) | `make-signing-identity.sh --export` |
| `SPARKLE_PRIVATE_KEY` | Signs updates; matches `SUPublicEDKey` in `Resources/Info.plist` | `sparkle.sh generate-key` |

**Keep private backups of all of them**, for example in a password manager.
- Losing or replacing the certificate makes every user grant Accessibility again (macOS ties the
  permission to the signature).
- Losing the Sparkle key means installed apps reject every future update, so users must
  download a new version by hand.

Never make a second certificate or a new key "to fix" something. Restore the backup instead.

## Why self-signed

MacCursor has no Apple Developer ID, so it isn't notarized. Users click **Open Anyway** once on
first launch (README → Install). Updates installed by Sparkle don't ask again, because they
carry the same signature.

## Recreating the secrets from the backup

```sh
base64 -i release-identity.p12 | gh secret set RELEASE_IDENTITY_P12_BASE64
gh secret set RELEASE_IDENTITY_PASSWORD < release-identity.password
gh secret set SPARKLE_PRIVATE_KEY < sparkle-private-key.txt
```

## Each release

1. Add a `## [X.Y.Z] - YYYY-MM-DD` section at the top of `CHANGELOG.md`, written for users.
   It becomes the release notes and the text in the update dialog.
2. Run the relevant rows of [manual-test.md](manual-test.md) with a local build.
3. Commit, then tag and push:

   ```sh
   git tag vX.Y.Z
   git push origin main vX.Y.Z
   ```

4. When the workflow finishes, the release has the zip, its checksum and `appcast.xml`.
   Update an installed copy with **Check for Updates…** and check that it relaunches as the new
   version with Accessibility still granted.

`./scripts/release.sh X.Y.Z` builds the same zip locally, signed with `CODESIGN_IDENTITY`
(default: your local identity).

## If a release is broken

Mark the GitHub release as a pre-release or delete it. The **Latest** link, and with it the
update feed, then points to the previous version, so no more apps update to the broken one.
Apps that already updated get the fix with the next patch version, so ship one soon. Don't
reuse or move a tag.

## Local builds

`./scripts/make-signing-identity.sh` makes a **MacCursor Local** identity once per Mac (macOS
asks for your login password to trust it). Local builds use it, so Accessibility survives
rebuilds. Local and release builds have different certificates, so each needs its own
Accessibility grant. Local builds never check for updates by themselves.
