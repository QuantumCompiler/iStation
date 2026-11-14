#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 iStation contributors
"""required-checks.py — keep stable's required checks equal to the pipelines' passing jobs (Apogee's form,
v0.0.1 item 4d).

  required-checks.py --pr <N>            propose: the checks that passed on pull request #N's head, from
                                         ci.yml and darwin.yml (never `tag and release`, which runs after
                                         a merge), as stable's required status checks
  required-checks.py --pr <N> --apply    set them on stable — it changes the repository's settings, so it
                                         is the user's to run
  required-checks.py --verify            stable's required checks as GitHub has them now

Run after a pipeline's jobs change, once the pull request's run has passed and before it merges. Needs gh,
signed in. Standard library only.
"""
import argparse
import json
import subprocess
import sys

BRANCH = "stable"
NEVER_REQUIRED = {"tag and release"}


def gh(*args, data=None):
    result = subprocess.run(["gh", *args], input=json.dumps(data) if data is not None else None,
                            capture_output=True, text=True)
    return result.returncode, result.stdout, result.stderr


def die(message):
    sys.exit(f"required-checks.py: {message}")


def current():
    code, out, err = gh("api", f"repos/{{owner}}/{{repo}}/branches/{BRANCH}/protection/required_status_checks")
    if code != 0:
        if "404" in err or "Not Found" in err or "not protected" in err.lower():
            return None
        die(f"could not read {BRANCH}'s required checks: {err.strip()}")
    return sorted(json.loads(out).get("contexts", []))


def passing(pr):
    code, out, err = gh("pr", "view", str(pr), "--json", "headRefOid,baseRefName")
    if code != 0:
        die(f"could not read pull request #{pr}: {err.strip()}")
    view = json.loads(out)
    if view["baseRefName"] != BRANCH:
        die(f"#{pr} is into {view['baseRefName']}, not {BRANCH}")
    code, out, err = gh("api", "--paginate", f"repos/{{owner}}/{{repo}}/commits/{view['headRefOid']}/check-runs",
                        "--jq", ".check_runs[] | [.name, .conclusion, .app.slug] | @tsv")
    if code != 0:
        die(f"could not read #{pr}'s checks: {err.strip()}")
    names, unfinished = set(), []
    for line in out.splitlines():
        name, conclusion, app = (line.split("\t") + ["", "", ""])[:3]
        if app != "github-actions" or name in NEVER_REQUIRED:
            continue
        if conclusion == "success":
            names.add(name)
        elif conclusion not in ("skipped", "neutral"):
            unfinished.append(f"{name} ({conclusion or 'running'})")
    if unfinished:
        die(f"#{pr}'s run hasn't passed: {', '.join(unfinished)} — propose once every job is green")
    return sorted(names)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--pr", type=int)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    if args.verify:
        checks = current()
        print(f"{BRANCH} requires: {', '.join(checks) if checks else 'nothing (not protected)'}")
        return
    if args.pr is None:
        parser.error("--pr <N> or --verify")
    proposed = passing(args.pr)
    if not proposed:
        die(f"#{args.pr} has no passing checks to require")
    now = current()
    print(f"{BRANCH} requires now: {', '.join(now) if now else 'nothing'}")
    print(f"proposed, from #{args.pr}'s passing jobs: {', '.join(proposed)}")
    if not args.apply:
        print("nothing changed: --apply sets them (the user's to run — it changes the repository's settings)")
        return
    if now is None:
        body = {"required_status_checks": {"strict": True, "contexts": proposed}, "enforce_admins": False,
                "required_pull_request_reviews": None, "restrictions": None}
        code, _, err = gh("api", "-X", "PUT", f"repos/{{owner}}/{{repo}}/branches/{BRANCH}/protection", "--input", "-", data=body)
    else:
        code, _, err = gh("api", "-X", "PATCH", f"repos/{{owner}}/{{repo}}/branches/{BRANCH}/protection/required_status_checks",
                          "--input", "-", data={"strict": True, "contexts": proposed})
    if code != 0:
        die(f"could not set {BRANCH}'s required checks: {err.strip()}")
    print(f"{BRANCH} now requires: {', '.join(proposed)}")


if __name__ == "__main__":
    main()
