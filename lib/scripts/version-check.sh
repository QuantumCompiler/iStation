#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 iStation contributors
#
# version-check.sh — CI's `version bump` check for a pull request into `stable`: what merging it would
# publish, and whether lib/release/VERSION allows it (v0.0.1 item 4c, Apogee's form).
#
#   version-check.sh [--branch <name>] [--latest <tag>] [--changed true|false] [--released true|false]
#
# lib/release/VERSION is the release, and the only thing that names one; a merge into `stable` publishes
# v<VERSION> unless that is already released (the user's call, 2026-11-14). So:
#   - VERSION holds x.y.z;
#   - a release branch, v<x.y.z>, is named for VERSION;
#   - with the apps' code changed since the latest release (anything under lib/src/ or lib/release/),
#     v<VERSION> must be unreleased, or the change ships in no release; with only documentation
#     changed, a released VERSION merges and publishes nothing — not an error.
# The flags are CI's answers, and a test's plants; without them it works each out: the branch (the pull
# request's head on a runner, else the current one), the latest release (latest-release.sh), what
# changed since its commit (git diff), and whether v<VERSION> is released (gh, else the tag on origin).
set -euo pipefail

fail() {  # fail <file> <message>
    [ -z "${GITHUB_ACTIONS:-}" ] || printf '::error file=%s::%s\n' "$1" "$2"
    printf 'version-check.sh: %s\n' "$2" >&2
    exit 1
}

usage="usage: version-check.sh [--branch <name>] [--latest <tag>] [--changed true|false] [--released true|false]"
branch="" latest="" latest_given=0 changed="" released=""
while [ $# -gt 0 ]; do
    case "$1" in
        --branch) branch="${2:-}"; shift 2 || fail lib/release/VERSION "$usage" ;;
        --latest) latest="${2:-}"; latest_given=1; shift 2 || fail lib/release/VERSION "$usage" ;;
        --changed) changed="${2:-}"; shift 2 || fail lib/release/VERSION "$usage" ;;
        --released) released="${2:-}"; shift 2 || fail lib/release/VERSION "$usage" ;;
        *) fail lib/release/VERSION "$usage" ;;
    esac
done

root="$(git rev-parse --show-toplevel 2>/dev/null)" || fail lib/release/VERSION "not inside a git repository"
scripts="$(cd "$(dirname "$0")" && pwd)"
version="$(tr -d ' \r\n' <"$root/lib/release/VERSION" 2>/dev/null)" || true
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail lib/release/VERSION "lib/release/VERSION must hold the release as x.y.z (got '$version')"
tag="v$version"

# The branch: a release branch is named for the release it builds.
[ -n "$branch" ] || branch="${GITHUB_HEAD_REF:-$(git -C "$root" rev-parse --abbrev-ref HEAD)}"
if [[ "$branch" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] && [ "$branch" != "$tag" ]; then
    fail lib/release/VERSION "the release branch is $branch but lib/release/VERSION says $version: they name the same release"
fi

# The latest release, and what changed since it.
if [ "$latest_given" = 0 ]; then
    found="$("$scripts/latest-release.sh")" || fail lib/release/VERSION "could not look up the latest release"
    latest="${found%% *}"
    since_commit="${found#* }"
else
    since_commit="$([ -z "$latest" ] || git -C "$root" rev-list -n 1 "$latest" 2>/dev/null || true)"
fi
if [ -z "$changed" ]; then
    if [ -z "$latest" ]; then
        changed=true  # no release yet: everything is new
    elif [ -n "$since_commit" ]; then
        if git -C "$root" diff --quiet "$since_commit" HEAD -- lib/src lib/release; then changed=false; else changed=true; fi
    else
        fail lib/release/VERSION "the latest release $latest has no commit here to compare with (fetch its tag)"
    fi
fi
case "$changed" in true | false) ;; *) fail lib/release/VERSION "--changed must be true or false (got '$changed')" ;; esac

# Is v<VERSION> released? "Not released" is an answer; "could not ask" is a failure.
if [ -z "$released" ]; then
    if command -v gh >/dev/null 2>&1 && { [ -n "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ] || gh auth status >/dev/null 2>&1; }; then
        set +e
        asked="$(gh api "repos/{owner}/{repo}/releases/tags/$tag" --silent 2>&1)"
        status=$?
        set -e
        if [ "$status" -eq 0 ]; then released=true
        elif grep -q 'HTTP 404' <<<"$asked"; then released=false
        else fail lib/release/VERSION "could not ask whether $tag is released (gh api exited $status)"
        fi
    else
        set +e
        git -C "$root" ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null 2>&1
        status=$?
        set -e
        case "$status" in
            0) released=true ;;
            2) released=false ;;
            *) fail lib/release/VERSION "could not ask origin whether $tag is released (git ls-remote exited $status)" ;;
        esac
    fi
fi
case "$released" in true | false) ;; *) fail lib/release/VERSION "--released must be true or false (got '$released')" ;; esac

since="${latest:-no release yet}"
if [ "$changed" = true ] && [ "$released" = true ]; then
    fail lib/release/VERSION "the apps' code changed since $since, but $tag is already released: bump lib/release/VERSION, or this merge publishes nothing and the change ships in no release"
fi
if [ "$released" = false ]; then
    message="merging publishes $tag: the source at the merge commit (latest release: $since)"
else
    message="$tag is already released and only documentation changed since $since: merging publishes nothing"
fi
printf '%s\n' "$message"
[ -z "${GITHUB_STEP_SUMMARY:-}" ] || printf '%s\n' "$message" >>"$GITHUB_STEP_SUMMARY"
