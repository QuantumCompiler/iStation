#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 iStation contributors
#
# changed.sh — has a pipeline's source changed between two commits? (Apogee's form, v0.0.1 item 4d)
#
#   changed.sh <pipeline> <from> <to>   answer on the last line: <pipeline>=true|false
#   changed.sh --paths <pipeline>       the paths it is built from, one per line
#
# Each application has its own pipeline, and it builds only when what the application is built from
# changed since the latest release; otherwise its required job reports under its name and passes, having
# built nothing. This file declares, once, what each pipeline is built from: today the Apple apps'
# (darwin). Documentation changes build no app. An empty <from> (nothing released yet), or a commit this
# repository doesn't have, answers true: when in doubt, build. On a runner the answer also goes to
# $GITHUB_OUTPUT.
set -euo pipefail

usage() { sed -n '7,8p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

paths_of() {
    case "$1" in
        darwin)
            echo "lib/src/darwin/"               # the package, the apps, the project, their scripts and tools
            echo "lib/release/VERSION"           # the release, which the apps report as their version
            echo "lib/scripts/cicd.sh"           # the one build path every build of them takes
            echo "lib/scripts/changed.sh"        # this declaration
            echo ".github/workflows/darwin.yml"  # their pipeline's own definition
            ;;
        *) printf 'changed.sh: no pipeline named %s (known: darwin)\n' "$1" >&2; exit 2 ;;
    esac
}

answer() {  # answer <pipeline> <true|false> <why>
    printf '%s\n' "$3"
    printf '%s=%s\n' "$1" "$2"
    [ -z "${GITHUB_OUTPUT:-}" ] || printf '%s=%s\n' "$1" "$2" >>"$GITHUB_OUTPUT"
    [ -z "${GITHUB_STEP_SUMMARY:-}" ] || printf '**%s:** %s\n\n' "$1" "$3" >>"$GITHUB_STEP_SUMMARY"
    exit 0
}

case "${1:-}" in
    --paths) [ $# -eq 2 ] || usage; paths_of "$2"; exit 0 ;;
    "" | -h | --help) usage ;;
esac
[ $# -eq 3 ] || usage
name="$1" from="$2" to="$3"
specs="$(paths_of "$name")"  # through a variable: an unknown name stops here, never diffs the whole tree
pathspecs=()
while IFS= read -r spec; do pathspecs+=("${spec%% *}"); done <<<"$specs"

[ -n "$from" ] || answer "$name" true "nothing released yet: the $name pipeline runs"
for commit in "$from" "$to"; do
    git cat-file -e "$commit^{commit}" 2>/dev/null || answer "$name" true "commit $commit is not in this repository: the $name pipeline runs"
done
changed="$(git diff --name-only "$from" "$to" -- "${pathspecs[@]}")"
[ -n "$changed" ] || answer "$name" false "unchanged since ${from:0:12}: the $name pipeline builds nothing"
count="$(printf '%s\n' "$changed" | wc -l | tr -d ' ')"
sed -n '1,10s/^/changed: /p' <<<"$changed"
answer "$name" true "$count of its files changed since ${from:0:12}: the $name pipeline runs"
