#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 iStation contributors
#
# latest-release.sh — the newest published release: its tag and its commit (Apogee's form).
#
#   latest-release.sh [--exclude <tag>]   prints "<tag> <commit>", or nothing when none is published
#
# "Published" is a release on GitHub, not a tag: a draft or a pre-release is not one. The commit is the
# tag's as the remote has it, never a local tag. Asks GitHub with gh when gh is signed in (on a runner,
# GH_TOKEN), else the public API with curl and python3. Run from inside the checkout.
set -euo pipefail

die() {
    [ -z "${GITHUB_ACTIONS:-}" ] || printf '::error title=latest-release.sh::%s\n' "$*"
    printf 'latest-release.sh: %s\n' "$*" >&2
    exit 1
}

exclude=""
case "${1:-}" in
    --exclude) [ $# -eq 2 ] || die "usage: latest-release.sh [--exclude <tag>]"; exclude="$2" ;;
    "") ;;
    *) die "usage: latest-release.sh [--exclude <tag>]" ;;
esac

repo="${GH_REPO:-${GITHUB_REPOSITORY:-}}"
if [ -z "$repo" ]; then
    url="$(git remote get-url origin 2>/dev/null)" || die "no origin remote to name the repository"
    repo="$(printf '%s\n' "$url" | sed -E 's#^(git@|ssh://git@|https://)github\.com[:/]##; s#\.git$##')"
fi

if command -v gh >/dev/null 2>&1 && { [ -n "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ] || gh auth status >/dev/null 2>&1; }; then
    tags="$(gh api "repos/$repo/releases?per_page=30" --jq '.[] | select((.draft | not) and (.prerelease | not)) | .tag_name')" ||
        die "could not list the releases of $repo"
else
    tags="$(curl -fsSL "https://api.github.com/repos/$repo/releases?per_page=30" | python3 -c 'import json, sys
for r in json.load(sys.stdin):
    if not r["draft"] and not r["prerelease"]:
        print(r["tag_name"])')" || die "could not list the releases of $repo"
fi

for tag in $tags; do
    [ "$tag" != "$exclude" ] || continue
    commit="$(git ls-remote origin "refs/tags/$tag^{}" | cut -f1)"
    [ -n "$commit" ] || commit="$(git ls-remote origin "refs/tags/$tag" | cut -f1)"
    [ -n "$commit" ] || die "release $tag has no tag on origin"
    printf '%s %s\n' "$tag" "$commit"
    exit 0
done
