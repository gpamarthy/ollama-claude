# Releasing

Maintainer's handbook. If you're not the maintainer you can ignore this file.

## SemVer

Pre-1.0:

- `0.x.0` for new features
- `0.x.y` for fixes
- Breaking changes are allowed but mentioned in CHANGELOG

Post-1.0 (when the Go-binary rewrite lands):

- `M.0.0` for breaking changes
- `M.N.0` for new features
- `M.N.P` for fixes

## Cadence

Biweekly tags through `v1.0`. Each release has a CHANGELOG entry and a GitHub Discussions post. Don't release silently; that's the trust signal that says "this is maintained."

## Cutting a release

```sh
# 1. Bump the version
vim CHANGELOG.md                       # move [Unreleased] entries under the new tag
git add CHANGELOG.md
git commit -m "chore: prepare v0.x.y"

# 2. Tag
git tag -a v0.x.y -m "v0.x.y"
git push origin main --tags

# 3. CI release.yml builds tarballs, generates SHA256SUMS, drafts the release.
# 4. Verify the draft on github.com/gpamarthy/ollama-claude/releases:
#    - both tarballs are attached
#    - SHA256SUMS is present and matches
#    - notes are accurate
# 5. Publish.

# 6. Post a "What's in v0.x.y" Discussions thread.
```

## Phase 2 cut-over

`v1.0.0` ships when:

- Feature parity with the latest Phase-1 release
- All eight test layers green (Layer 1-4 on PR, 5-8 nightly green for 7+ days)
- Cosign signatures live and verified on the last three releases
- `docs/RELEASING.md` updated with the Go-toolchain steps
- Homebrew tap, WinGet manifest, scoop bucket green and tested

After Phase 2, `install.sh` swaps "fetch shell-script tarball" for "fetch Go binary tarball." The on-disk schema and subcommand tree are unchanged, so users don't notice.

## Don't

- Don't `--amend` a tag. Cut a new patch.
- Don't add Co-Authored-By or AI markers to commits on the public repo.
- Don't ship anything that breaks the layered config schema without a major-version bump (post-1.0) or a CHANGELOG warning (pre-1.0).
