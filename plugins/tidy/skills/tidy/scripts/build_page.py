#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = []
# ///
"""Build the /tidy checklist page from the five findings files.

Usage: build_page.py <run_dir> [--sample]

Reads  <run_dir>/findings/{interface,memory,skills,connectors,scheduled}.json
Writes <run_dir>/page/index.html and <run_dir>/page/state.json

The page keeps its findings inline. Ticks live in state.json, which the page
saves itself (artifact files form). Claude reads state.json back after "Begin".
State ticks: {row id: {"action": label, "comment": text}}.
"""

import argparse
import json
import re
from pathlib import Path
from typing import Any

type Row = dict[str, Any]
type Part = dict[str, Any]

PARTS = ["interface", "memory", "skills", "connectors", "scheduled"]
EM_DASH, EN_DASH = "\u2014", "\u2013"
BANNED = [(EM_DASH, "em dash"), (EN_DASH, "en dash")]
BANNED_WORD = re.compile(r"\bship(s|ped|ping)?\b", re.IGNORECASE)
CONTEXT_ROW = re.compile(r"\|\s*([A-Za-z ()]+?)\s*\|\s*([\d.]+)(k?)\s*\|")
# Rows whose default action edits a file or changes nothing are counted per row,
# because two edits to one file both save context.
PER_ROW_KINDS = ("edit_file", "create_file", "task_update", "none", None)
CONTEXT_CATEGORY = {"skills": "Skills", "memory": "Memory files"}


def load_findings(run_dir: Path) -> tuple[list[Part], list[str]]:
    """Load the findings file of every part that exists.

    Args:
        run_dir: The run folder that holds `findings/`.

    Returns:
        The loaded parts in `PARTS` order, and the names of the parts whose file
        is missing.

    Raises:
        json.JSONDecodeError: If a findings file is not valid JSON.

    """
    out: list[Part] = []
    missing: list[str] = []
    for part in PARTS:
        path = run_dir / "findings" / f"{part}.json"
        if not path.exists():
            missing.append(part)
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        data.setdefault("part", part)
        data.setdefault("title", part.title())
        out.append(data)
    return out, missing


def check_row(row: Row, table: Row, seen: set[str]) -> list[str]:
    """Check one row and repair what can be repaired safely.

    Args:
        row: The row to check. Modified in place when a field is repaired.
        table: The table that holds the row.
        seen: The ids of the rows checked so far. Updated with this row's id.

    Returns:
        One message per problem found.

    """
    problems: list[str] = []
    rid = row.get("id")
    if not rid:
        problems.append(f"{table.get('id')}: row without id")
    else:
        if rid in seen:
            problems.append(f"duplicate row id {rid}")
        seen.add(rid)
    if row.get("tick"):
        problems.append(f"{rid}: pre-ticked, forcing false")
        row["tick"] = False
    if row.get("mode") not in ("approve", "flag", "info"):
        problems.append(f"{rid}: bad mode {row.get('mode')}, set to info")
        row["mode"] = "info"
    n_cells, n_cols = len(row.get("cells", [])), len(table.get("columns", []))
    if n_cells != n_cols:
        problems.append(f"{rid}: {n_cells} cells for {n_cols} columns")
    if row["mode"] == "approve":
        actions = row.get("actions") or []
        if not actions or not all(
            isinstance(a, dict) and a.get("label") and a.get("apply") for a in actions
        ):
            problems.append(
                f"{rid}: approve row needs actions with label and apply, set to flag",
            )
            row["mode"] = "flag"
        elif not isinstance(row.get("default"), int) or not 0 <= row["default"] < len(
            actions,
        ):
            problems.append(f"{rid}: bad default, set to 0")
            row["default"] = 0
    tokens = row.get("tokens")
    if tokens is not None and (not isinstance(tokens, int | float) or tokens < 0):
        problems.append(f"{rid}: tokens must be a number or null, set to null")
        row["tokens"] = None
    return problems


def check(findings: list[Part]) -> list[str]:
    """Check every row and the banned text.

    Checks for duplicate ids, pre-ticked rows, bad modes, cell and column
    counts, approve rows without actions, a bad default, bad token values and
    banned text. Repairs what it safely can.

    Args:
        findings: The loaded parts. Rows are modified in place.

    Returns:
        One message per problem found.

    """
    problems: list[str] = []
    seen: set[str] = set()
    for part in findings:
        for table in part.get("tables", []):
            for row in table.get("rows", []):
                problems.extend(check_row(row, table, seen))
    text = json.dumps(findings, ensure_ascii=False)
    problems.extend(
        f"{text.count(char)} x {name} in findings"
        for char, name in BANNED
        if char in text
    )
    problems.extend(
        f"banned word found (s-h-i-p{m})" for m in set(BANNED_WORD.findall(text))
    )
    return problems


def target_key(row: Row) -> tuple[str | None, Any]:
    """Name what the default action touches, so one skill or connector counts once.

    Args:
        row: A findings row.

    Returns:
        The kind of the default action and a reference to its target.

    """
    actions = row.get("actions") or []
    index = row.get("default", 0)
    apply = (actions[index] if 0 <= index < len(actions) else {}).get("apply", {})
    if apply.get("kind") in PER_ROW_KINDS:
        return (apply.get("kind"), row.get("id"))
    ref = (
        apply.get("path")
        or apply.get("id")
        or apply.get("name")
        or apply.get("service")
        or row.get("id")
    )
    if isinstance(ref, str):
        ref = ref.removesuffix("/SKILL.md")
    return (apply.get("kind"), ref)


def savings(findings: list[Part]) -> tuple[int, bool, dict[str, int]]:
    """Total the context tokens saved per chat if every approve row takes its default.

    Rows that touch the same target count once, and the biggest number wins.

    Args:
        findings: The loaded parts.

    Returns:
        The total, whether any contributing number is an estimate, and the total
        per part.

    """
    best: dict[tuple[Any, Any], int] = {}
    estimated = False
    for part in findings:
        for table in part.get("tables", []):
            for row in table.get("rows", []):
                if row.get("mode") == "approve" and row.get("tokens"):
                    key = (part.get("part"), target_key(row)[1])
                    best[key] = max(best.get(key, 0), row["tokens"])
                    estimated = estimated or bool(row.get("tokens_est"))
    by_part: dict[str, int] = {}
    for (name, _), value in best.items():
        by_part[name] = by_part.get(name, 0) + value
    return int(sum(best.values())), estimated, by_part


def context_categories(run_dir: Path) -> dict[str, int]:
    """Read the category totals from the /context table, when the run has one.

    Args:
        run_dir: The run folder that holds `raw/context_usage.txt`.

    Returns:
        Tokens per category name, empty when the file is missing.

    """
    path = run_dir / "raw" / "context_usage.txt"
    if not path.exists():
        return {}
    out: dict[str, int] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if m := CONTEXT_ROW.match(line):
            out[m.group(1)] = int(float(m.group(2)) * (1000 if m.group(3) else 1))
    return out


def clean_text(findings: list[Part]) -> list[Part]:
    """Swap dashes for commas so the page never shows them.

    Args:
        findings: The loaded parts.

    Returns:
        A copy of the parts with the dashes replaced.

    """
    raw = json.dumps(findings, ensure_ascii=False)
    raw = raw.replace(f" {EM_DASH} ", ", ").replace(EM_DASH, ", ").replace(EN_DASH, "-")
    return json.loads(raw)


def inline(obj: object) -> str:
    """Serialise a value for a script tag, so `</script>` cannot end the tag early.

    Args:
        obj: Any JSON-serialisable value.

    Returns:
        The JSON text with `</` escaped.

    """
    return json.dumps(obj, ensure_ascii=False).replace("</", "<\\/")


def mark_target_keys(findings: list[Part]) -> None:
    """Tag each approve row with its target, which the page uses to count a target once.

    Args:
        findings: The loaded parts. Rows are modified in place.

    """
    for part in findings:
        for table in part.get("tables", []):
            for row in table.get("rows", []):
                if row.get("mode") == "approve":
                    row["tkey"] = f"{part.get('part')}|{target_key(row)[1]}"


def main() -> None:
    """Build the page and state files, then print a summary and the check results."""
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("run_dir", type=Path)
    parser.add_argument("--sample", action="store_true")
    args = parser.parse_args()

    run_dir = args.run_dir.resolve()
    template = (
        Path(__file__).resolve().parent.parent / "assets" / "page.html"
    ).read_text(encoding="utf-8")

    findings, missing = load_findings(run_dir)
    problems = check(findings)
    findings = clean_text(findings)

    tables = [t for p in findings for t in p.get("tables", [])]
    rows = [r for t in tables for r in t.get("rows", [])]
    folders = sorted({r["folder"] for r in rows if r.get("folder")})
    total, estimated, by_part = savings(findings)
    mark_target_keys(findings)
    n_approve = sum(1 for r in rows if r.get("mode") == "approve")
    meta = {
        "run": run_dir.name,
        "sample": args.sample,
        "subtitle": (
            f"Run of {run_dir.name}. {n_approve} changes to review, "
            f"{len(rows)} rows in all. Nothing changes until you tick it."
        ),
        "folders": folders,
        "savings": total,
        "savings_est": estimated,
    }
    # ticks: {row id: {"action": <label>, "comment": <text>}}
    # comments: {row id: text} for unticked rows
    state = {"status": "draft", "ticks": {}, "comments": {}, "report": []}

    html = (
        template.replace("__FINDINGS__", inline(findings))
        .replace("__META__", inline(meta))
        .replace("__STATE__", inline(state))
    )

    out = run_dir / "page"
    out.mkdir(parents=True, exist_ok=True)
    (out / "index.html").write_text(html, encoding="utf-8")
    (out / "state.json").write_text(json.dumps(state, indent=2), encoding="utf-8")

    print(f"page: {out / 'index.html'}")
    print(
        f"parts: {len(findings)}  missing: {missing or 'none'}  "
        f"rows: {len(rows)}  approve: {n_approve}",
    )
    print(
        f"approve all saves: {total} tokens per chat"
        f"{' (est.)' if estimated else ''}  folders: {len(folders)}",
    )
    measured = context_categories(run_dir)
    for part, value in sorted(by_part.items()):
        cap = measured.get(CONTEXT_CATEGORY.get(part, ""))
        flag = "  OVER MEASURED, FIX" if cap is not None and value > cap else ""
        cap_note = f" (measured {part} total: {cap})" if cap is not None else ""
        print(f"  {part}: {value} tokens{cap_note}{flag}")
    for problem in problems:
        print("check:", problem)


if __name__ == "__main__":
    main()
