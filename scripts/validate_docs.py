#!/usr/bin/env python3
"""Validate a project-construction docs system.

Checks, for every docs home under DOCS_ROOT (a directory holding backlog/README.md):
  - every index row's File link resolves, and every backlog document has a row (both ways);
  - a row's document sits in its table's directory (Version cell: arch. -> architecture/,
    maint. -> maintenance/, a version -> that version's directory);
  - ids are unique within the home;
  - every Status cell carries one status (🟢 🔒 🚧 ❌), and every 🔒 gate names a pending id
    (in the same home, or "<id> (<home>)" for another home);
and across DOCS_ROOT plus every CLAUDE.md and SKILL.md in the repository: every relative
Markdown link resolves (code spans and fenced blocks are ignored, as are template placeholders).

Usage:
  validate_docs.py DOCS_ROOT [--repo REPO_ROOT] [--ignore SUBSTRING ...]

Exit status 0 when clean, 1 when any error was found. Standard library only.
"""

import argparse
import re
import sys
from pathlib import Path

STATUSES = ("🟢", "🔒", "🚧", "❌")
SKIP_DIRS = {".git", "node_modules", "build", "dist", "out", "target", ".venv", "venv",
             "__pycache__", "third_party", "vendor", "_deps", "worktrees", "DerivedData", ".build"}
LINK = re.compile(r"(?<!\!)\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
FENCE = re.compile(r"^\s*(```|~~~)")
CODE_SPAN = re.compile(r"(`+)(.+?)\1")
ID = re.compile(r"^[A-Za-z]?\d+[a-z]?$")
GATE_TOKEN = re.compile(r"\b([A-Z]?\d+[a-z]?)\b(?:\s*\(([^)]+)\))?")


def strip_code(lines):
    """Yield (line_number, text) with fenced blocks dropped and code spans blanked."""
    in_fence = False
    for number, line in enumerate(lines, 1):
        if FENCE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        yield number, CODE_SPAN.sub("", line)


def cells(row):
    parts = row.strip().strip("|").split("|")
    return [p.strip() for p in parts]


def clean_id(cell):
    return re.sub(r"[*`~]", "", cell).strip()


def table_dir_for(version):
    v = version.strip().strip("`").lower()
    if v.startswith("arch"):
        return "architecture"
    if v.startswith("maint"):
        return "maintenance"
    return version.strip().strip("`")


def parse_index(readme):
    """Return the index rows: dicts with id, file, version, status, line."""
    rows = []
    header = None
    lines = readme.read_text(encoding="utf-8").splitlines()
    for number, line in enumerate(lines, 1):
        if not line.lstrip().startswith("|"):
            header = None
            continue
        row = cells(line)
        if header is None:
            lowered = [c.lower().strip("* ") for c in row]
            if "#" in lowered and "file" in lowered and "status" in lowered:
                header = {name: lowered.index(name) for name in ("#", "file", "status")}
                if "version" in lowered:
                    header["version"] = lowered.index("version")
            continue
        if set("".join(row)) <= set("-: "):
            continue
        if len(row) <= max(header.values()):
            continue
        link = LINK.search(row[header["file"]])
        rows.append({
            "id": clean_id(row[header["#"]]),
            "file": link.group(1) if link else None,
            "version": row[header["version"]] if "version" in header else None,
            "status": row[header["status"]],
            "line": number,
        })
    return rows


def check_home(home, all_pending, errors):
    backlog = home / "backlog"
    readme = backlog / "README.md"
    rows = parse_index(readme)
    seen = {}
    linked = set()
    for r in rows:
        where = f"{readme}:{r['line']}"
        if not ID.match(r["id"]):
            errors.append(f"{where}: unrecognised id {r['id']!r}")
        if r["id"] in seen:
            errors.append(f"{where}: id {r['id']} repeats line {seen[r['id']]}")
        seen[r["id"]] = r["line"]
        if not r["file"]:
            errors.append(f"{where}: row {r['id']} has no File link")
        else:
            target = (backlog / r["file"].split("#")[0]).resolve()
            linked.add(target)
            if not target.is_file():
                errors.append(f"{where}: row {r['id']} links a missing document {r['file']}")
            if r["version"]:
                expected = table_dir_for(r["version"])
                actual = Path(r["file"]).parts[0] if len(Path(r["file"]).parts) > 1 else ""
                if expected and actual != expected:
                    errors.append(f"{where}: row {r['id']} (Version {r['version']}) links into "
                                  f"{actual or 'the backlog root'}/, expected {expected}/")
        found = [s for s in STATUSES if s in r["status"]]
        if len(found) != 1:
            errors.append(f"{where}: row {r['id']} needs exactly one status of {' '.join(STATUSES)}")
    for doc in backlog.rglob("*.md"):
        if doc.name == "README.md":
            continue
        if doc.resolve() not in linked:
            errors.append(f"{doc}: backlog document has no index row")
    return rows


def check_gates(home_rows, errors):
    homes_by_name = {home.name.lower(): home for home in home_rows}
    for home, (readme, rows) in home_rows.items():
        pending = {r["id"] for r in rows}
        for r in rows:
            if "🔒" not in r["status"]:
                continue
            gate_text = r["status"].split("🔒", 1)[1]
            tokens = GATE_TOKEN.findall(re.sub(r"[*`]", "", gate_text))
            if not tokens:
                errors.append(f"{readme}:{r['line']}: row {r['id']} is 🔒 but names no gate")
            for gate_id, other in tokens:
                target_ids = pending
                if other:
                    other_home = homes_by_name.get(other.strip().lower())
                    if other_home is None:
                        errors.append(f"{readme}:{r['line']}: gate {gate_id} names an unknown home ({other})")
                        continue
                    target_ids = {x["id"] for x in home_rows[other_home][1]}
                if gate_id not in target_ids:
                    errors.append(f"{readme}:{r['line']}: row {r['id']} is gated on {gate_id}, "
                                  f"which is not a pending item")


def markdown_files(docs_root, repo_root):
    files = set(docs_root.rglob("*.md"))
    for name in ("CLAUDE.md", "SKILL.md"):
        for path in repo_root.rglob(name):
            if not any(part in SKIP_DIRS for part in path.relative_to(repo_root).parts):
                files.add(path)
    return sorted(f for f in files if not any(part in SKIP_DIRS for part in f.parts))


def check_links(files, ignores, errors):
    count = 0
    for path in files:
        for number, text in strip_code(path.read_text(encoding="utf-8").splitlines()):
            for match in LINK.finditer(text):
                target = match.group(1).strip("<>")
                if re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I) or target.startswith("#"):
                    continue
                if "{{" in target or any(s in f"{path}:{number}:{target}" for s in ignores):
                    continue
                count += 1
                resolved = (path.parent / target.split("#")[0]).resolve()
                if not resolved.exists():
                    errors.append(f"{path}:{number}: broken link {target}")
    return count


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("docs_root", type=Path)
    parser.add_argument("--repo", type=Path, help="repository root (default: the nearest parent with .git)")
    parser.add_argument("--ignore", action="append", default=[],
                        help="skip links whose 'path:line:target' contains this substring (repeatable)")
    args = parser.parse_args()

    docs_root = args.docs_root.resolve()
    if not docs_root.is_dir():
        sys.exit(f"not a directory: {docs_root}")
    repo_root = args.repo.resolve() if args.repo else next(
        (p for p in [docs_root, *docs_root.parents] if (p / ".git").exists()), docs_root)

    errors = []
    home_rows = {}
    for readme in sorted(docs_root.rglob("backlog/README.md")):
        if any(part in SKIP_DIRS for part in readme.parts):
            continue
        home = readme.parent.parent
        home_rows[home] = (readme, check_home(home, None, errors))
    check_gates(home_rows, errors)
    files = markdown_files(docs_root, repo_root)
    links = check_links(files, args.ignore, errors)

    for home, (_, rows) in home_rows.items():
        print(f"home {home.relative_to(repo_root) if home.is_relative_to(repo_root) else home}: "
              f"{len(rows)} index rows")
    print(f"links: {links} relative links checked across {len(files)} files")
    if errors:
        print(f"\n{len(errors)} error(s):")
        prefix = f"{repo_root}/"
        for e in errors:
            print(f"  {e.replace(prefix, '')}")
        sys.exit(1)
    print("ALL CLEAN")


if __name__ == "__main__":
    main()
