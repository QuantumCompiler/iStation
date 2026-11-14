#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 iStation contributors
#
# pr-ci.sh — rehearse, on this machine, the CI run a pull request into `stable` starts (Apogee's form,
# v0.0.1 item 4d): the same jobs, on the same source.
#
#   pr-ci.sh [--base <ref>] [--uncommitted]   rehearse; exits non-zero if CI would fail
#   pr-ci.sh --clean                          remove its worktrees
#
# CI doesn't build the branch: it builds GitHub's test merge of the branch into `stable`, and so does
# this — it fetches the base (origin/stable unless --base says otherwise), merges it into HEAD in a
# temporary worktree, and runs each pipeline's jobs there through the scripts the workflows call:
#
#   docs              lib/scripts/cicd.sh --docs                       (ci.yml)
#   version bump      lib/scripts/version-check.sh, the branch's name   (ci.yml)
#   what changed      lib/scripts/changed.sh darwin, since the latest release   (darwin.yml)
#   build darwin      lib/scripts/cicd.sh --app darwin --test, when the apps changed   (darwin.yml)
#
# Uncommitted changes aren't rehearsed — a pull request carries commits — unless --uncommitted, which
# rehearses them as a commit no branch points at. `tag and release` isn't either: it publishes, and only
# a merge runs it (lib/scripts/release-from-pr.sh <pr> rehearses that).
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"
WORK="${TMPDIR:-/tmp}/istation-pr-ci"
base="origin/stable" uncommitted=0
while [ $# -gt 0 ]; do
    case "$1" in
        --base) base="${2:-}"; shift ;;
        --uncommitted) uncommitted=1 ;;
        --clean) git worktree list --porcelain | sed -n "s#^worktree \($WORK/.*\)#\1#p" | while read -r w; do git worktree remove --force "$w"; done
                 rm -rf "$WORK"; echo "removed $WORK"; exit 0 ;;
        -h | --help) sed -n '8,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "pr-ci.sh: unknown argument $1" >&2; exit 2 ;;
    esac
    shift
done

branch="$(git rev-parse --abbrev-ref HEAD)"
head="HEAD"
dirty="$(git status --porcelain)"
if [ "$uncommitted" = 1 ] && [ -n "$dirty" ]; then
    # Every file git doesn't ignore, new ones included, as a commit no branch points at.
    index="$(mktemp)"
    trap 'rm -f "$index"' EXIT
    cp "$(git rev-parse --git-path index)" "$index"
    GIT_INDEX_FILE="$index" git add -A
    head="$(git -c user.name=pr-ci -c user.email=pr-ci@localhost commit-tree "$(GIT_INDEX_FILE="$index" git write-tree)" -p HEAD -m "pr-ci.sh: uncommitted changes")"
    echo "rehearsing uncommitted changes too, as ${head:0:12}"
elif [ -n "$dirty" ]; then
    echo "note: uncommitted changes are left out — a pull request carries commits (--uncommitted rehearses them)"
fi
case "$base" in origin/*) git fetch -q origin "${base#origin/}" ;; esac

mkdir -p "$WORK"
tree="$WORK/merge-$(date +%s)"
git worktree add -q --detach "$tree" "$head"
if ! git -C "$tree" -c user.name=pr-ci -c user.email=pr-ci@localhost merge -q --no-edit "$base" >/dev/null 2>&1; then
    echo "the branch doesn't merge cleanly into $base: CI can't build the test merge either"
    exit 1
fi
echo "rehearsing the test merge of $branch into $base, in $tree"

results=()
run() {  # run <job> <command…>
    local job="$1"; shift
    printf '\n== %s\n' "$job"
    if (cd "$tree" && "$@"); then results+=("passed  $job"); else results+=("FAILED  $job"); fi
}
run "docs" lib/scripts/cicd.sh --docs
run "version bump" lib/scripts/version-check.sh --branch "$branch"
printf '\n== what changed (darwin)\n'
answer="" commit=""
if found="$(cd "$tree" && lib/scripts/latest-release.sh)"; then
    [ -z "$found" ] || commit="${found#* }"
    if answer="$(cd "$tree" && lib/scripts/changed.sh darwin "$commit" HEAD)"; then
        printf '%s\n' "$answer"
        results+=("passed  what changed (darwin)")
    else
        results+=("FAILED  what changed (darwin)")
    fi
else
    results+=("FAILED  what changed (darwin): the latest release couldn't be looked up")
fi
case "$(tail -n 1 <<<"$answer")" in
    darwin=true) run "build darwin" lib/scripts/cicd.sh --app darwin --test ;;
    darwin=false) results+=("passed  build darwin (unchanged: nothing to build)") ;;
    *) results+=("FAILED  build darwin (no answer from what changed)") ;;
esac

printf '\n== the verdict\n'
printf '  %s\n' "${results[@]}"
git worktree remove --force "$tree"
for r in "${results[@]}"; do [[ "$r" != FAILED* ]] || { echo "CI would fail"; exit 1; }; done
echo "CI would pass"
