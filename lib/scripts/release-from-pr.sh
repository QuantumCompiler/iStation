#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 iStation contributors
#
# release-from-pr.sh — tag and publish the release a merged pull request into `stable` makes
# (v0.0.1 item 4c, Apogee's form).
#
#   release-from-pr.sh <pr-number>             rehearse: every check, no changes
#   release-from-pr.sh <pr-number> --publish   tag the merge commit v<VERSION> and publish its release
#
# The merge is the release (the user's call, 2026-11-14): CI's `tag and release` job runs this with
# --publish once a pull request into `stable` merges. A release is iStation's source at the merge commit,
# which GitHub archives with it; the apps ship through the App Stores, and their submission stays the
# user's. In order, each a hard stop:
#   1. The pull request: into `stable`, and merged when publishing. Its merge commit is what is released.
#   2. The release: lib/release/VERSION at that commit names it.
#   3. A tag v<VERSION> at ANOTHER commit means that version is out, and this merge publishes nothing —
#      how a documentation merge declines to cut a release (exit 0). A tag at THIS commit with its release
#      is done; with none, publishing finishes what an earlier attempt started.
#   4. The tag and the release in one `gh release create`, so no tag is left without its release.
# Needs gh (GH_TOKEN on a runner, or signed in) and a checkout holding the merge commit.
set -euo pipefail

RELEASE_BRANCH="${RELEASE_BRANCH:-stable}"

die() {
    [ -z "${GITHUB_ACTIONS:-}" ] || printf '::error title=release-from-pr::%s\n' "$*"
    printf 'release-from-pr: %s\n' "$*" >&2
    exit 1
}
note() {
    printf '%s\n' "$*"
    [ -z "${GITHUB_STEP_SUMMARY:-}" ] || printf '%s\n' "$*" >>"$GITHUB_STEP_SUMMARY"
}

pr="" publish=0
while [ $# -gt 0 ]; do
    case "$1" in
        --publish) publish=1 ;;
        -h | --help) sed -n '5,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) [ -z "$pr" ] || die "one pull request number, please (got '$pr' and '$1')"; pr="$1" ;;
    esac
    shift
done
[[ "$pr" =~ ^[0-9]+$ ]] || die "usage: release-from-pr.sh <pr-number> [--publish]"
command -v gh >/dev/null 2>&1 || die "gh is needed"

# 1. The pull request.
read -r base state commit title < <(gh pr view "$pr" --json baseRefName,state,mergeCommit,title \
    --jq '[.baseRefName, .state, (.mergeCommit.oid // "-"), .title] | @tsv') || die "could not read pull request #$pr"
[ "$base" = "$RELEASE_BRANCH" ] || die "#$pr is into $base, not $RELEASE_BRANCH: only a merge into $RELEASE_BRANCH is a release"
if [ "$state" != MERGED ]; then
    [ "$publish" = 0 ] || die "#$pr is $state, not merged: a release is merged code"
    note "#$pr is $state: when it merges into $RELEASE_BRANCH, its merge commit is released (rehearsal, nothing published)"
    exit 0
fi

# 2. The release its merge commit names.
git cat-file -e "$commit^{commit}" 2>/dev/null || git fetch -q origin "$commit" || die "the merge commit $commit isn't in this checkout"
version="$(git show "$commit:lib/release/VERSION" 2>/dev/null | tr -d ' \r\n')"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "lib/release/VERSION at $commit must hold x.y.z (got '$version')"
tag="v$version"

# 3. Is that version out already?
tagged="$(git ls-remote origin "refs/tags/$tag^{}" | cut -f1)"
[ -n "$tagged" ] || tagged="$(git ls-remote origin "refs/tags/$tag" | cut -f1)"
if [ -n "$tagged" ] && [ "$tagged" != "$commit" ]; then
    note "$tag is already released at ${tagged:0:12}: #$pr's merge publishes nothing"
    exit 0
fi
if [ -n "$tagged" ] && gh release view "$tag" >/dev/null 2>&1; then
    note "$tag is already released at this merge commit: nothing left to do"
    exit 0
fi

# 4. The tag and the release, together.
if [ "$publish" = 0 ]; then
    note "rehearsal: would tag ${commit:0:12} as $tag and publish the release \"iStation $tag\" (#$pr: $title)"
    exit 0
fi
gh release create "$tag" --target "$commit" --title "iStation $tag" --generate-notes ||
    die "gh release create $tag failed"
note "published $tag at ${commit:0:12} (#$pr: $title)"
