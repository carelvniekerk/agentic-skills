#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = []
# ///
"""Read-only gather step for /tidy.

Reads the Claude setup from disk and writes raw JSON files. It changes nothing.

Usage: gather_local.py <out_dir> [--days 30] [--active "/path/a,/path/b"]

Writes into <out_dir>:
  sessions.json    Code-tab sessions (title, folder, last active, archived, model)
  folders.json     folders with session counts, to propose the active ones
  scheduled.json   scheduled tasks, last runs, failures, model per run
  mods.json        mods, what they do, on or off
  skills.json      every SKILL.md on the machine, with location, use count, last used
  connectors.json  MCP servers seen in chats, with call count and last used
  context.json     global CLAUDE.md, memory folders, and per active folder: route files,
                   sub-folders missing a CLAUDE.md or index, recent context files
  The summary printed at the end lists every file that could not be read.
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import time
from collections import defaultdict
from dataclasses import asdict, dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    from collections.abc import Iterator

type Json = dict[str, Any]

HOME = Path.home()
APP = HOME / "Library/Application Support/Claude"
CODE_SESSIONS = APP / "claude-code-sessions"
COWORK_SESSIONS = APP / "local-agent-mode-sessions"
PROJECTS = HOME / ".claude/projects"
NOW = time.time()

DAY_SECONDS = 86400
MS_PER_SECOND = 1000
ERROR_CHARS = 200
DESCRIPTION_CHARS = 400
CHARS_PER_TOKEN = 4
RUNS_KEPT = 10
MIN_RECENT_SESSIONS = 2
MAX_RECENT_FILES = 40
ISO_SECONDS_LENGTH = 19
TOOL_RE = r'"name":"(Skill|mcp__[^"]+)","input"'
MIN_MCP_NAME_PARTS = 2
SKIP_DIRS = {
    "node_modules",
    ".git",
    "Caches",
    "Cache",
    ".Trash",
    ".npm",
    ".cache",
    "Library/Caches",
    "site-packages",
    ".venv",
    "venv",
    "dist",
    "build",
    ".next",
}
ROUTE_NAMES = ("index.md", "map.md", "readme.md")
CONTEXT_NAMES = ("CLAUDE.md", "AGENTS.md")

# Files that could not be read. The scan keeps going, but the summary names them
# so that a count that is too low is visible.
UNREADABLE: list[str] = []


@dataclass
class Session:
    """One Code-tab or Cowork session as read from its local JSON file."""

    id: str | None
    title: str
    cwd: str
    created_days_ago: float
    last_active_days_ago: float
    archived: bool
    model: str | None
    scheduled_task: str | None
    error: str
    last: float


@dataclass
class SkillUse:
    """Calls of one skill seen in the transcripts."""

    uses: int = 0
    last: float = 0.0
    where: set[str] = field(default_factory=set)


@dataclass
class McpUse:
    """Calls of one MCP server seen in the transcripts."""

    calls: int = 0
    last: float = 0.0
    tools: set[str] = field(default_factory=set)


def age_days(ts: float) -> float:
    """Convert an epoch time to days before now.

    Args:
        ts: Seconds since the epoch.

    Returns:
        The age in days, rounded to one decimal.

    """
    return round((NOW - ts) / DAY_SECONDS, 1)


def iso_to_epoch(text: str) -> float | None:
    """Parse the first 19 characters of an ISO timestamp as UTC.

    Args:
        text: A timestamp such as `2026-11-19T09:30:00.000Z`.

    Returns:
        Seconds since the epoch, or None when the text is not a timestamp.

    """
    try:
        return (
            datetime.fromisoformat(text[:ISO_SECONDS_LENGTH])
            .replace(tzinfo=UTC)
            .timestamp()
        )
    except ValueError:
        return None


def read_json(path: Path) -> Any:  # noqa: ANN401
    """Read a JSON file and record it in `UNREADABLE` when that fails.

    Args:
        path: The file to read.

    Returns:
        The parsed value, or None when the file is unreadable or not JSON.

    """
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except OSError, ValueError:
        UNREADABLE.append(str(path))
        return None


def read_text(path: Path) -> str | None:
    """Read a text file and record it in `UNREADABLE` when that fails.

    Args:
        path: The file to read.

    Returns:
        The text with undecodable bytes replaced, or None when the file is unreadable.

    """
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        UNREADABLE.append(str(path))
        return None


def frontmatter(text: str) -> dict[str, str]:
    """Read the flat key and value pairs of a YAML front matter block.

    Args:
        text: The content of a SKILL.md file.

    Returns:
        The keys with their values joined onto one line, empty without front matter.

    """
    m = re.match(r"^---\s*\n(.*?)\n---", text, re.DOTALL)
    out: dict[str, str] = {}
    if not m:
        return out
    key = None
    for line in m.group(1).splitlines():
        km = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if km:
            key = km.group(1)
            out[key] = km.group(2).strip().strip('"').strip("'")
        elif key and line.startswith((" ", "\t")):
            out[key] = (out[key] + " " + line.strip()).strip()
    return out


# ---------- sessions ----------


def read_sessions(root: Path) -> list[Session]:
    """Read every session file below a sessions root, newest first.

    Args:
        root: The Code or Cowork sessions folder.

    Returns:
        The sessions sorted by last activity, empty when the folder is missing.

    """
    rows: list[Session] = []
    if root.exists():
        for f in root.glob("*/*/local_*.json"):
            d = read_json(f)
            if not isinstance(d, dict):
                continue
            created = (d.get("createdAt") or 0) / MS_PER_SECOND
            last = (d.get("lastActivityAt") or d.get("createdAt") or 0) / MS_PER_SECOND
            rows.append(
                Session(
                    id=d.get("sessionId"),
                    title=d.get("title") or "",
                    cwd=d.get("cwd") or "",
                    created_days_ago=age_days(created),
                    last_active_days_ago=age_days(last),
                    archived=bool(d.get("isArchived")),
                    model=d.get("model"),
                    scheduled_task=d.get("scheduledTaskId"),
                    error=(d.get("error") or "")[:ERROR_CHARS],
                    last=last,
                ),
            )
    rows.sort(key=lambda r: -r.last)
    return rows


def gather_folders(sessions: list[Session], days: int) -> list[Json]:
    """Count sessions per working folder and propose the active ones.

    Args:
        sessions: The Code-tab sessions.
        days: The window that counts as recent.

    Returns:
        One row per folder, the most recently used first. A folder is proposed
        as active when it has at least two recent sessions.

    """
    by: dict[str, Json] = defaultdict(
        lambda: {"sessions": 0, "recent": 0, "last_active_days_ago": None},
    )
    for s in sessions:
        if s.scheduled_task:
            continue
        b = by[s.cwd]
        b["sessions"] += 1
        if s.last_active_days_ago <= days:
            b["recent"] += 1
        if (
            b["last_active_days_ago"] is None
            or s.last_active_days_ago < b["last_active_days_ago"]
        ):
            b["last_active_days_ago"] = s.last_active_days_ago
    out: list[Json] = [
        {"folder": k, **v, "proposed_active": v["recent"] >= MIN_RECENT_SESSIONS}
        for k, v in by.items()
        if k
    ]
    out.sort(key=lambda r: (-r["recent"], -r["sessions"]))
    return out


# ---------- scheduled tasks ----------


def gather_scheduled(sessions: list[Session]) -> list[Json]:
    """List scheduled tasks with their last runs.

    Code tab tasks live in ~/.claude/scheduled-tasks, Cowork tasks in
    ~/Documents/Claude/Scheduled. Cowork runs are Cowork sessions with a
    scheduledTaskId.

    Args:
        sessions: The Code-tab sessions.

    Returns:
        One row per task folder, with failures and models of its last ten runs.

    """
    runs: dict[str, list[Session]] = defaultdict(list)
    for s in [*sessions, *read_sessions(COWORK_SESSIONS)]:
        if s.scheduled_task:
            runs[s.scheduled_task].append(s)
    tasks: list[Json] = []
    homes = [
        ("code", HOME / ".claude/scheduled-tasks"),
        ("cowork", HOME / "Documents/Claude/Scheduled"),
    ]
    for where, base in homes:
        for d in sorted(base.glob("*/")) if base.exists() else []:
            sk = d / "SKILL.md"
            text = read_text(sk) if sk.exists() else None
            fm = frontmatter(text) if text else {}
            last = sorted(runs.get(d.name, []), key=lambda x: -x.last)
            recent = last[:RUNS_KEPT]
            tasks.append(
                {
                    "id": d.name,
                    "where": where,
                    "description": fm.get("description", ""),
                    "runs_seen": len(last),
                    "last_run_days_ago": recent[0].last_active_days_ago
                    if recent
                    else None,
                    "failures_last_10": sum(1 for x in recent if x.error),
                    "last_error": next((x.error for x in recent if x.error), ""),
                    "models_last_10": sorted({x.model for x in recent if x.model}),
                    "path": str(sk),
                },
            )
    return tasks


# ---------- mods ----------


def gather_mods() -> Json:
    """List the mods and whether each is switched on.

    Returns:
        `present` is False when there is no mods folder.

    """
    base = HOME / ".claude/mods"
    if not base.exists():
        return {"present": False, "mods": []}
    switches = (
        read_json(base / "switches.json") if (base / "switches.json").exists() else {}
    )
    if not isinstance(switches, dict):
        switches = {}
    mods: list[Json] = []
    for d in sorted(p for p in base.iterdir() if p.is_dir()):
        pj = d / ".claude-plugin/plugin.json"
        manifest = read_json(pj) if pj.exists() else None
        desc = manifest.get("description", "") if isinstance(manifest, dict) else ""
        mods.append(
            {
                "name": d.name,
                "description": desc,
                "on": bool(switches.get(d.name, True)),
                "hidden": bool(switches.get(d.name + ":hidden", False)),
            },
        )
    return {"present": True, "mods": mods}


# ---------- log scan (skill calls and MCP calls) ----------


def grep_lines(roots: list[Path], include: str) -> Iterator[str]:
    """Yield the transcript lines that hold a Skill or MCP tool call.

    Uses ripgrep when it exists, then the ripgrep embedded in the claude binary,
    then grep.

    Args:
        roots: The folders to search. Missing ones are skipped.
        include: The file name glob to search.

    Yields:
        One matching line at a time.

    """
    paths = [str(r) for r in roots if r.exists()]
    if not paths:
        return
    executable = None
    if rg := shutil.which("rg"):
        cmd = [
            rg,
            "--no-filename",
            "--no-messages",
            "-g",
            include,
            "-e",
            TOOL_RE,
            *paths,
        ]
    else:
        claude = os.environ.get("CLAUDE_CODE_EXECPATH") or str(
            HOME / ".local/bin/claude",
        )
        if os.access(claude, os.X_OK):
            # The claude binary acts as ripgrep when argv[0] is "rg".
            cmd = [
                "rg",
                "--no-filename",
                "--no-messages",
                "-g",
                include,
                "-e",
                TOOL_RE,
                *paths,
            ]
            executable = claude
        else:
            cmd = ["grep", "-rhE", "--include", include, TOOL_RE, *paths]
    # The arguments are fixed strings and paths, and no shell is involved.
    with subprocess.Popen(  # noqa: S603
        cmd,
        executable=executable,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        errors="replace",
    ) as p:
        if p.stdout is not None:
            yield from p.stdout


def tool_uses(line: str) -> tuple[float, list[Json]]:
    """Extract the timestamp and the tool_use blocks of one transcript line.

    Args:
        line: One JSON line of a transcript.

    Returns:
        The timestamp as epoch seconds (0 when absent) and the tool_use blocks.
        Both are empty or zero when the line is not valid JSON.

    """
    try:
        d = json.loads(line)
    except ValueError:
        return 0.0, []
    ts = iso_to_epoch(d.get("timestamp") or d.get("_audit_timestamp") or "") or 0.0
    m = d.get("message")
    content = m.get("content") if isinstance(m, dict) else None
    if not isinstance(content, list):
        return ts, []
    return ts, [
        b for b in content if isinstance(b, dict) and b.get("type") == "tool_use"
    ]


def scan_logs() -> tuple[Json, list[Json]]:
    """Count skill calls and MCP calls in the Code and Cowork transcripts.

    Returns:
        The skill usage by skill name, and the MCP usage per server, the most
        recently used first.

    """
    skills: dict[str, SkillUse] = defaultdict(SkillUse)
    mcp: dict[str, McpUse] = defaultdict(McpUse)
    sources = [
        (PROJECTS, "*.jsonl", "code"),
        (COWORK_SESSIONS, "audit.jsonl", "cowork"),
    ]
    for root, include, where in sources:
        for line in grep_lines([root], include):
            ts, blocks = tool_uses(line)
            for b in blocks:
                name = b.get("name", "")
                if name == "Skill":
                    skill = (b.get("input") or {}).get("skill") or ""
                    if skill:
                        entry = skills[skill]
                        entry.uses += 1
                        entry.last = max(entry.last, ts)
                        entry.where.add(where)
                elif name.startswith("mcp__"):
                    parts = name.split("__")
                    server = parts[1] if len(parts) > MIN_MCP_NAME_PARTS else name
                    m_entry = mcp[server]
                    m_entry.calls += 1
                    m_entry.last = max(m_entry.last, ts)
                    m_entry.tools.add(parts[-1])
    skills_out = {
        k: {
            "uses": v.uses,
            "last_used_days_ago": age_days(v.last) if v.last else None,
            "where": sorted(v.where),
        }
        for k, v in skills.items()
    }
    mcp_out = [
        {
            "server": k,
            "calls": v.calls,
            "tools_used": len(v.tools),
            "last_used_days_ago": age_days(v.last) if v.last else None,
        }
        for k, v in mcp.items()
    ]
    mcp_out.sort(
        key=lambda r: (r["last_used_days_ago"] is None, r["last_used_days_ago"] or 0),
    )
    return skills_out, mcp_out


# ---------- skills on disk ----------


def find_skill_files() -> Iterator[Path]:
    """Find every SKILL.md below the folders where skills live.

    Yields:
        Each distinct file once, by resolved path.

    """
    roots = [
        HOME / ".claude",
        HOME / "Documents",
        HOME / "dev",
        HOME / "Desktop",
        HOME / "Projects",
        APP / "local-agent-mode-sessions/skills-plugin",
    ]
    seen: set[Path] = set()
    for root in roots:
        if not root.exists():
            continue
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [
                d for d in dirnames if d not in SKIP_DIRS and not d.startswith("._")
            ]
            if "/.claude/projects" in dirpath or "/scheduled-tasks" in dirpath:
                dirnames[:] = []
                continue
            if "SKILL.md" in filenames:
                path = Path(dirpath) / "SKILL.md"
                resolved = path.resolve()
                if resolved not in seen:
                    seen.add(resolved)
                    yield path


def enabled_plugins() -> set[str]:
    """Read the names of the plugins that settings.json enables.

    Returns:
        The plugin names without their marketplace suffix, empty when
        settings.json is missing or unreadable.

    """
    path = HOME / ".claude/settings.json"
    if not path.exists():
        return set()
    d = read_json(path)
    if not isinstance(d, dict):
        return set()
    return {k.split("@")[0] for k, v in (d.get("enabledPlugins") or {}).items() if v}


def plugin_location(path: str, enabled: set[str]) -> str:
    """Classify a SKILL.md below the plugins folder.

    synced = org plugins pushed by the Claude app, cache = installed plugins and
    marketplaces = catalogue copies that are never loaded.

    Args:
        path: The file path as a string.
        enabled: The enabled plugin names.

    Returns:
        `plugin` when the plugin is synced or enabled, otherwise `plugin-stored`.

    """
    if "/plugins/synced/" in path:
        return "plugin"
    m = re.search(r"/plugins/cache/[^/]+/([^/]+)/", path)
    return "plugin" if m and m.group(1) in enabled else "plugin-stored"


def location_of(path: Path, enabled: set[str]) -> str:
    """Classify where a SKILL.md sits.

    Args:
        path: The SKILL.md file.
        enabled: The enabled plugin names.

    Returns:
        One of `desktop-harness`, `global`, `plugin`, `plugin-stored`, `folder`
        or `loose`. A `loose` file sits outside any skills folder, so it is a
        copy or a source and is not loaded.

    """
    s = str(path)
    if "/local-agent-mode-sessions/skills-plugin/" in s:
        return "desktop-harness"
    if s.startswith(str(HOME / ".claude/skills")):
        return "global"
    if s.startswith(str(HOME / ".claude/plugins")):
        return plugin_location(s, enabled)
    if "/.claude/skills/" in s:
        return "folder"
    return "loose"


def match_usage(name: str, usage: Json) -> Json | None:
    """Find the usage entry of a skill by plain name or `plugin:name`.

    Args:
        name: The skill name.
        usage: The skill usage from `scan_logs`.

    Returns:
        The usage entry, or None when the skill was never called.

    """
    if name in usage:
        return usage[name]
    return next((v for k, v in usage.items() if k.split(":")[-1] == name), None)


def gather_skills(usage: Json) -> list[Json]:
    """Describe every SKILL.md on disk with its location and use count.

    Args:
        usage: The skill usage from `scan_logs`.

    Returns:
        One row per file, sorted by name and location.

    """
    enabled = enabled_plugins()
    rows: list[Json] = []
    for p in find_skill_files():
        text = read_text(p)
        if text is None:
            continue
        fm = frontmatter(text)
        desc = fm.get("description", "")
        row: Json = {
            "name": fm.get("name") or p.parent.name,
            "location": location_of(p, enabled),
            "path": str(p),
            "description": desc[:DESCRIPTION_CHARS],
            "desc_tokens": max(1, len(desc) // CHARS_PER_TOKEN),
            "body_lines": text.count("\n"),
            "manual_only": fm.get("disable-model-invocation", "").lower() == "true",
            "md5": hashlib.md5(text.encode(), usedforsecurity=False).hexdigest(),
        }
        u = match_usage(row["name"], usage)
        row["uses"] = u["uses"] if u else 0
        row["last_used_days_ago"] = u["last_used_days_ago"] if u else None
        row["used_in"] = u["where"] if u else []
        rows.append(row)
    by_name: dict[str, list[Json]] = defaultdict(list)
    for r in rows:
        by_name[r["name"]].append(r)
    for r in rows:
        r["copies"] = len(by_name[r["name"]])
        r["identical_copies"] = sum(
            1 for x in by_name[r["name"]] if x["md5"] == r["md5"]
        )
    rows.sort(key=lambda r: (r["name"], r["location"]))
    return rows


# ---------- context files ----------


def top_dirs(folder: Path) -> list[Json]:
    """List the top-level sub-folders and whether each has a CLAUDE.md or index.

    Args:
        folder: The project folder.

    Returns:
        One row per sub-folder, without hidden, underscore and skipped folders.

    """
    out: list[Json] = []
    for d in sorted(
        x
        for x in folder.iterdir()
        if x.is_dir() and x.name not in SKIP_DIRS and not x.name.startswith((".", "_"))
    ):
        names = {f.name.lower() for f in d.iterdir() if f.is_file()}
        out.append(
            {
                "name": d.name,
                "has_claude_md": "claude.md" in names,
                "has_index": bool(names & set(ROUTE_NAMES)),
            },
        )
    return out


def scan_markdown(folder: Path, days: int) -> tuple[int, list[Json], list[Json]]:
    """Walk a project folder for Markdown files.

    Args:
        folder: The project folder.
        days: The window that counts as recent.

    Returns:
        The number of Markdown files, the route files (CLAUDE.md, AGENTS.md and
        index files) and the other files changed within the window, newest first.

    """
    count = 0
    route: list[Json] = []
    recent: list[Json] = []
    for dirpath, dirnames, filenames in os.walk(folder):
        dirnames[:] = [
            d for d in dirnames if d not in SKIP_DIRS and not d.startswith(".")
        ]
        for fn in filenames:
            if not fn.endswith(".md"):
                continue
            count += 1
            p = Path(dirpath) / fn
            try:
                st = p.stat()
            except OSError:
                UNREADABLE.append(str(p))
                continue
            row = {
                "path": str(p),
                "bytes": st.st_size,
                "modified_days_ago": age_days(st.st_mtime),
            }
            if fn in CONTEXT_NAMES or fn.lower() in ROUTE_NAMES:
                route.append(row)
            elif row["modified_days_ago"] <= days:
                recent.append(row)
    recent.sort(key=lambda r: r["modified_days_ago"])
    return count, route, recent[:MAX_RECENT_FILES]


def gather_project_context(folder: str, days: int) -> Json:
    """Describe the context files of one active folder.

    Args:
        folder: The folder path as confirmed by the user.
        days: The window that counts as recent.

    Returns:
        Whether the folder exists, its root CLAUDE.md or AGENTS.md, route files,
        top-level folders and recently changed Markdown files.

    """
    fp = Path(folder)
    proj: Json = {
        "folder": folder,
        "exists": fp.exists(),
        "root_claude_md": None,
        "route_files": [],
        "top_dirs": [],
        "recent_context": [],
        "md_files": 0,
    }
    if not fp.exists():
        return proj
    for name in CONTEXT_NAMES:
        if (fp / name).exists() and (text := read_text(fp / name)) is not None:
            proj["root_claude_md"] = {"path": str(fp / name), "lines": text.count("\n")}
            break
    proj["top_dirs"] = top_dirs(fp)
    proj["md_files"], proj["route_files"], proj["recent_context"] = scan_markdown(
        fp,
        days,
    )
    return proj


def gather_context(active: list[str], days: int = 30) -> Json:
    """Describe the global layer plus one entry per active folder.

    Args:
        active: The folders the user confirmed as active.
        days: The window that counts as recent.

    Returns:
        The global CLAUDE.md, the memory folders and one entry per active folder.

    """
    out: Json = {"global_claude_md": None, "memory_dirs": [], "projects": []}
    g = HOME / ".claude/CLAUDE.md"
    if g.exists() and (t := read_text(g)) is not None:
        out["global_claude_md"] = {
            "path": str(g),
            "lines": t.count("\n"),
            "chars": len(t),
        }
    for m in PROJECTS.glob("*/memory") if PROJECTS.exists() else []:
        files = list(m.glob("*.md"))
        out["memory_dirs"].append(
            {
                "path": str(m),
                "files": len(files),
                "chars": sum(f.stat().st_size for f in files),
            },
        )
    out["projects"] = [gather_project_context(folder, days) for folder in active]
    return out


def main() -> None:
    """Gather the raw files into the output folder and print a summary."""
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("out_dir", type=Path)
    parser.add_argument("--days", type=int, default=30)
    parser.add_argument("--active", default="")
    args = parser.parse_args()

    out: Path = args.out_dir
    out.mkdir(parents=True, exist_ok=True)
    started = time.time()

    sessions = read_sessions(CODE_SESSIONS)
    cowork_count = (
        len(list(COWORK_SESSIONS.glob("*/*/local_*")))
        if COWORK_SESSIONS.exists()
        else 0
    )
    folders = gather_folders(sessions, args.days)
    active = [a for a in args.active.split(",") if a] or [
        f["folder"] for f in folders if f["proposed_active"]
    ]
    usage, mcp = scan_logs()
    skills = gather_skills(usage)
    files = {
        "sessions.json": {
            "code_sessions": [
                {k: v for k, v in asdict(s).items() if k != "last"} for s in sessions
            ],
            "cowork_session_count": cowork_count,
        },
        "folders.json": {"days": args.days, "folders": folders, "active_used": active},
        "scheduled.json": gather_scheduled(sessions),
        "mods.json": gather_mods(),
        "skills.json": {"skills": skills, "skill_calls_seen": usage},
        "connectors.json": {"servers_seen_in_chats": mcp},
        "context.json": gather_context(active, args.days),
    }
    for name, data in files.items():
        (out / name).write_text(json.dumps(data, indent=1), encoding="utf-8")
    summary = {
        "out": str(out),
        "seconds": round(time.time() - started, 1),
        "code_sessions": len(sessions),
        "cowork_sessions": cowork_count,
        "skills_on_disk": len(skills),
        "mcp_servers_seen": len(mcp),
        "active_folders": active,
        "unreadable_files": len(UNREADABLE),
        "unreadable_examples": UNREADABLE[:10],
    }
    print(json.dumps(summary, indent=1))


if __name__ == "__main__":
    main()
