#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = []
# ///
"""Deterministic drift checks for design documents written by architecture-design.

A design drifts when the code changes after the design was approved. This script
does the checks a tool can do and leaves the semantic question (does the code
still do what the design says) to the implement:drift-reviewer agent.

Subcommands:

    scan [PATH ...]  Check implemented designs and print JSON on stdout and a
                     summary on stderr. Exit 0 when clean, 1 when there are
                     findings, 2 on an error that is not a finding. Writes nothing.
    gate             SessionStart hook. Reads the hook input on stdin and prints
                     one additionalContext message when a drift pass is due.
                     Always exits 0 and prints nothing otherwise.
    record           Store the current digests in .implement/drift-state.json,
                     after a completed drift pass.
    ignore           Keep .implement/ out of git through .git/info/exclude, unless
                     a gitignore already covers it.

Only designs with `status: implemented` are scanned. A design that is approved
but not built has no code to drift from, so scanning it would report every
identifier as missing. Acceptance tests are found through the `tests:` list in
the design frontmatter, which implement:implement writes when it marks the
design implemented.
"""

# ruff: noqa: S603, S607
# git and the boundary tools run by fixed name with paths as arguments, never
# through a shell, so the two subprocess rules have nothing to catch here.
import argparse
import fnmatch
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

STATE_PATH = Path(".implement") / "drift-state.json"
STATE_VERSION = 1
GATE_PATH = Path(".implement") / "drift-gate.json"
COOLDOWN_HOURS = 24
MIN_AGE_DAYS = 7
DEFAULT_DESIGN_DIR = "docs/design"
BOUNDARY_TIMEOUT_SECONDS = 120
OUTPUT_LIMIT = 4000
MAX_FILE_BYTES = 1_000_000

CODE_EXTENSIONS = frozenset(
    {".py", ".pyi", ".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".rs", ".go"},
)
# Identifiers also live in schema and shape files, as prefixed names such as mx:Shape.
SOURCE_EXTENSIONS = CODE_EXTENSIONS | frozenset({".ttl", ".jsonld"})
PATH_EXTENSIONS = CODE_EXTENSIONS | frozenset(
    {".json", ".toml", ".yaml", ".yml", ".md", ".sh", ".cfg", ".ini", ".txt", ".sql"},
)
# Files of these types are mostly runtime output, caches and examples in a design,
# so a missing one is not drift. They still count as references when they exist.
DATA_EXTENSIONS = frozenset(
    {".json", ".jsonld", ".csv", ".txt", ".sql", ".ttl", ".yaml", ".yml"},
)
SKIP_DIRS = frozenset(
    {
        ".git",
        "node_modules",
        ".venv",
        "venv",
        "__pycache__",
        ".mypy_cache",
        ".ruff_cache",
        "dist",
        "build",
    },
)
# A token with one of these characters is a template, a flag or a URL, not a path.
NOT_A_PATH = re.compile(r"[\s*<>{}$|]|://|^[-~/@]")
IDENTIFIER = re.compile(r"^[A-Za-z_]\w*$")
BACKTICK = re.compile(r"`([^`\n]+)`")
AC_ROW = re.compile(r"^\|\s*(AC-\d+)\s*\|", re.MULTILINE)
PY_TEST_ID = re.compile(r"\bdef\s+test_ac_(\d+)")
JS_TEST_ID = re.compile(r"""\b(?:it|test)(?:\.\w+)?\s*\(\s*["'`]AC-(\d+)""")
DESIGN_DIR_HINT = re.compile(
    r"design\s+(?:dir(?:ectory)?|documents?|docs)[^`\n]*`([^`\n]+)`",
    re.IGNORECASE,
)


@dataclass
class BoundaryResult:
    """The outcome of one boundary tool run, or the reason it could not run."""

    code: int | None  # None means the tool did not run
    output: str


class ScanError(Exception):
    """An error that is not a finding, such as a design path that does not exist."""


@dataclass
class Design:
    """One design document with its parsed frontmatter and body."""

    path: Path
    rel: str
    text: str
    meta: dict[str, Any]
    body_offset: int  # number of lines before the first line after the frontmatter

    @property
    def status(self) -> str:
        """The design's status, lower-cased, or an empty string."""
        return str(self.meta.get("status", "")).strip().lower()


@dataclass
class Report:
    """Everything one scan found."""

    designs: list[dict[str, Any]] = field(default_factory=list)
    findings: list[dict[str, Any]] = field(default_factory=list)
    not_run: list[dict[str, Any]] = field(default_factory=list)
    state_error: str | None = None


def find_root(start: Path) -> Path:
    """Return the git top level of `start`, or `start` outside a repository."""
    try:
        out = subprocess.run(
            ["git", "-C", str(start), "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=True,
            timeout=10,
        ).stdout.strip()
    except OSError, subprocess.SubprocessError:
        return start.resolve()
    return Path(out).resolve() if out else start.resolve()


def design_dir_for(root: Path, override: str | None) -> Path:
    """Resolve the design directory: override, project CLAUDE.md, then default."""
    if override:
        return (
            (root / override).resolve()
            if not Path(override).is_absolute()
            else Path(override)
        )
    claude_md = root / "CLAUDE.md"
    if claude_md.is_file():
        match = DESIGN_DIR_HINT.search(
            claude_md.read_text(encoding="utf-8", errors="replace"),
        )
        if match:
            return (root / match.group(1)).resolve()
    return (root / DEFAULT_DESIGN_DIR).resolve()


def _unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":  # noqa: PLR2004
        return value[1:-1]
    return value


def _parse_scalar(value: str) -> str | list[str]:
    value = value.strip()
    if value.startswith("[") and value.endswith("]"):
        inner = value[1:-1].strip()
        return [_unquote(item) for item in inner.split(",")] if inner else []
    return _unquote(value)


def parse_frontmatter(text: str) -> tuple[dict[str, Any], int]:
    """Parse the leading YAML frontmatter without a YAML library.

    Supports `key: value`, inline lists and block lists, which is all the
    design template uses.

    Args:
        text: The whole document.

    Returns:
        The parsed keys and the number of lines the frontmatter occupies.

    """
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return {}, 0
    meta: dict[str, Any] = {}
    key: str | None = None
    for index, line in enumerate(lines[1:], start=1):
        if line.strip() == "---":
            return meta, index + 1
        stripped = line.strip()
        if (
            stripped.startswith("- ")
            and key is not None
            and isinstance(meta.get(key), list)
        ):
            meta[key].append(_parse_scalar(stripped[2:]))
        elif ":" in line and not line.startswith((" ", "\t")):
            key, _, value = line.partition(":")
            key = key.strip()
            meta[key] = _parse_scalar(value) if value.strip() else []
    return {}, 0


def load_design(path: Path, root: Path) -> Design:
    """Read one design document."""
    text = path.read_text(encoding="utf-8", errors="replace")
    meta, offset = parse_frontmatter(text)
    try:
        rel = path.resolve().relative_to(root).as_posix()
    except ValueError:
        rel = path.as_posix()
    return Design(path=path, rel=rel, text=text, meta=meta, body_offset=offset)


def collect_designs(paths: list[str], design_dir: Path, root: Path) -> list[Design]:
    """Load the designs named on the command line, or every one in the design directory.

    Raises:
        ScanError: If a named path does not exist.

    """
    files: list[Path] = []
    targets = [Path(p) for p in paths] or [design_dir]
    for named in targets:
        target = named if named.is_absolute() else Path.cwd() / named
        if target.is_dir():
            files.extend(sorted(target.rglob("*.md")))
        elif target.is_file():
            files.append(target)
        elif paths:
            msg = f"no such design or directory: {target}"
            raise ScanError(msg)
    return [load_design(f, root) for f in files]


def inline_tokens(design: Design) -> list[tuple[int, str]]:
    """Return each inline backticked token outside code fences, with its line."""
    tokens: list[tuple[int, str]] = []
    in_fence = False
    for number, line in enumerate(design.text.splitlines(), start=1):
        if number <= design.body_offset:
            continue
        if line.lstrip().startswith(("```", "~~~")):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        tokens.extend((number, m.group(1).strip()) for m in BACKTICK.finditer(line))
    return tokens


def path_candidate(token: str) -> str | None:
    """Return the repository path a token names, or None when it is not a path."""
    if NOT_A_PATH.search(token) or token.startswith(".implement"):
        return None
    token = re.sub(r":\d+(?:-\d+)?$", "", token)
    token = token.split("::", 1)[0]
    if "/" in token:
        return token
    suffix = Path(token).suffix
    return token if suffix in PATH_EXTENSIONS and not token.startswith(".") else None


def identifier_candidate(token: str) -> str | None:
    """Return the code identifier a token names, or None for prose and flags.

    A bare lower-case word is too likely to be prose, and a bare snake_case
    token is as likely to be a config key, a field or a column as a function.
    Only calls (`name()`) and CamelCase names are checked, so a renamed function
    that the design mentions without parentheses goes unreported.
    """
    called = token.endswith("()")
    name = token.removesuffix("()").rsplit(".", 1)[-1]
    if not IDENTIFIER.match(name) or len(name) < 4:  # noqa: PLR2004
        return None
    mixed = re.search(r"[a-z]", name) and re.search(r"[A-Z]", name)
    if called or mixed:
        return name
    return None


def list_files(root: Path) -> list[str]:
    """List the repository files relative to `root`, except ignored ones."""
    try:
        out = subprocess.run(
            [
                "git",
                "-C",
                str(root),
                "ls-files",
                "--cached",
                "--others",
                "--exclude-standard",
            ],
            capture_output=True,
            text=True,
            check=True,
            timeout=30,
        ).stdout
        return sorted(
            {line for line in out.splitlines() if line and (root / line).is_file()},
        )
    except OSError, subprocess.SubprocessError:
        found: list[str] = []
        for base, dirs, names in os.walk(root):
            dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
            found.extend(Path(base, n).relative_to(root).as_posix() for n in names)
        return sorted(found)


class Repo:
    """A lazy view of the repository's files and source text."""

    def __init__(self, root: Path, design_dir: Path) -> None:
        """Remember the root and the design directory, which the source search skips."""
        self.root = root
        self.design_dir = design_dir
        self._files: list[str] | None = None
        self._sources: dict[str, str] | None = None

    @property
    def files(self) -> list[str]:
        """Every file in the repository."""
        if self._files is None:
            self._files = list_files(self.root)
        return self._files

    @property
    def sources(self) -> dict[str, str]:
        """The text of every code file outside the design directory."""
        if self._sources is None:
            sources: dict[str, str] = {}
            for rel in self.files:
                full = self.root / rel
                if full.suffix not in SOURCE_EXTENSIONS or full.is_relative_to(
                    self.design_dir,
                ):
                    continue
                try:
                    if full.stat().st_size <= MAX_FILE_BYTES:
                        sources[rel] = full.read_text(
                            encoding="utf-8",
                            errors="replace",
                        )
                except OSError:
                    continue
            self._sources = sources
        return self._sources

    def path_exists(self, candidate: str) -> bool:
        """Say whether a path exists, also when the design drops a leading package."""
        if (self.root / candidate).exists():
            return True
        return any(f == candidate or f.endswith("/" + candidate) for f in self.files)

    def is_unverifiable(self, candidate: str) -> str | None:
        """Return why a missing path says nothing about drift, or None.

        A path into a sibling repository cannot be checked from here, a
        data file is runtime output more often than source, and a path made of
        one-letter directories is an example.
        """
        parts = Path(candidate).parts
        if (
            parts
            and parts[0] not in {".", ".."}
            and not (self.root / parts[0]).exists()
            and (self.root.parent / parts[0]).is_dir()
        ):
            return "points into a sibling directory"
        if Path(candidate).suffix in DATA_EXTENSIONS:
            return "is a data file"
        if len(parts) > 1 and all(len(part) == 1 for part in parts[:-1]):
            return "looks like an example path"
        return None

    def has_identifier(self, name: str) -> bool:
        """Say whether a code file mentions the identifier as a whole word."""
        pattern = re.compile(rf"(?<!\w){re.escape(name)}(?!\w)")
        return any(
            name in text and pattern.search(text) for text in self.sources.values()
        )


def referenced_files(design: Design, repo: Repo) -> list[str]:
    """Return the existing files a design names in paths and in `tests:`.

    The gate hook and the scan both use this set for the digest, so it is kept
    to what needs no search of the source tree.
    """
    found: set[str] = set()
    for _, token in inline_tokens(design):
        candidate = path_candidate(token)
        if candidate and (repo.root / candidate).is_file():
            found.add(candidate)
    found.update(test_files(design, repo))
    return sorted(found)


def test_files(design: Design, repo: Repo) -> list[str]:
    """Expand the design's `tests:` entries, which may be globs, to existing files."""
    entries = design.meta.get("tests", [])
    if isinstance(entries, str):
        entries = [entries]
    found: set[str] = set()
    for entry in entries:
        if (repo.root / entry).is_file():
            found.add(entry)
            continue
        found.update(f for f in repo.files if fnmatch.fnmatch(f, entry))
    return sorted(found)


def digest(files: list[str], root: Path) -> str:
    """Hash file content, so a checkout that only touches mtimes changes nothing."""
    h = hashlib.sha256()
    for rel in files:
        try:
            content = hashlib.sha256((root / rel).read_bytes()).hexdigest()
        except OSError:
            content = "MISSING"
        h.update(f"{rel}\0{content}\n".encode())
    return h.hexdigest()


def finding(kind: str, design: Design, line: int, detail: str) -> dict[str, Any]:
    """Build one finding record."""
    return {"kind": kind, "design": design.rel, "line": line, "detail": detail}


def check_existence(design: Design, repo: Repo) -> list[dict[str, Any]]:
    """Report backticked paths and identifiers that no longer exist, once per token."""
    findings: list[dict[str, Any]] = []
    seen: set[str] = set()
    for line, token in inline_tokens(design):
        if token in seen:
            continue
        seen.add(token)
        path = path_candidate(token)
        if path is not None:
            if not repo.path_exists(path) and not repo.is_unverifiable(path):
                findings.append(
                    finding("MISSING", design, line, f"path `{path}` does not exist"),
                )
            continue
        name = identifier_candidate(token)
        if name is not None and not repo.has_identifier(name):
            findings.append(
                finding(
                    "MISSING",
                    design,
                    line,
                    f"identifier `{name}` is not in any source file",
                ),
            )
    return findings


def test_ids(files: list[str], root: Path) -> set[str]:
    """Return the criterion IDs that test names in the given files carry."""
    ids: set[str] = set()
    for rel in files:
        text = (root / rel).read_text(encoding="utf-8", errors="replace")
        ids.update(f"AC-{n}" for n in PY_TEST_ID.findall(text))
        ids.update(f"AC-{n}" for n in JS_TEST_ID.findall(text))
    return ids


def check_criteria(
    design: Design,
    repo: Repo,
) -> tuple[list[dict[str, Any]], str | None]:
    """Map the design's acceptance criteria to the tests it lists.

    Returns:
        The findings, and a reason when the check could not run.

    """
    criteria = {
        m.group(1): design.text.count("\n", 0, m.start()) + 1
        for m in AC_ROW.finditer(design.text)
    }
    if not criteria:
        return [], "the design has no acceptance criteria table"
    files = test_files(design, repo)
    if not files:
        return [], "no existing test file is listed under `tests:` in the frontmatter"
    present = test_ids(files, repo.root)
    findings = [
        finding("UNTESTED", design, line, f"{ac} has no test whose name carries the ID")
        for ac, line in criteria.items()
        if ac not in present
    ]
    findings.extend(
        finding(
            "ORPHAN",
            design,
            0,
            f"{ac} is in a listed test file and in no criterion of this design",
        )
        for ac in sorted(
            present - criteria.keys(),
            key=lambda s: int(s.removeprefix("AC-")),
        )
    )
    return findings, None


def _tool(root: Path, relative: str, on_path: str | None = None) -> str | None:
    local = root / relative
    if local.is_file():
        return str(local)
    return shutil.which(on_path) if on_path else None


def _boundary_command(name: str, root: Path) -> tuple[list[str] | None, str]:
    """Return the command for a boundary tool, or None with the reason it cannot run."""
    if name == "import-linter":
        exe = _tool(root, ".venv/bin/lint-imports", "lint-imports")
        configured = (root / ".importlinter").is_file() or any(
            "importlinter" in (root / f).read_text(encoding="utf-8", errors="replace")
            for f in ("pyproject.toml", "setup.cfg")
            if (root / f).is_file()
        )
        if not configured:
            return None, "no import-linter configuration in the project"
        return ([exe] if exe else None), "lint-imports is not installed"
    if name == "dependency-cruiser":
        exe = _tool(root, "node_modules/.bin/depcruise")
        configs = sorted(root.glob(".dependency-cruiser.*"))
        if not configs:
            return None, "no .dependency-cruiser configuration in the project"
        target = "src" if (root / "src").is_dir() else "."
        return ([exe, "--config", str(configs[0]), target] if exe else None), (
            "node_modules/.bin/depcruise is not installed"
        )
    exe = _tool(root, "node_modules/.bin/biome")
    return (
        [exe, "lint", "."] if exe else None
    ), "node_modules/.bin/biome is not installed"


def boundary_tools(design: Design) -> list[tuple[str, int]]:
    """Return the boundary tools a design names, with the line of the first mention."""
    lowered = design.text.lower()
    wanted = {
        "import-linter": ("import-linter", "lint-imports", "importlinter"),
        "dependency-cruiser": ("dependency-cruiser", "depcruise", "dependency cruiser"),
        "biome": ("biome",),
    }
    found: list[tuple[str, int]] = []
    for name, needles in wanted.items():
        positions = [lowered.find(n) for n in needles if n in lowered]
        if name == "biome" and "import" not in lowered:
            continue
        if positions:
            found.append((name, design.text.count("\n", 0, min(positions)) + 1))
    return found


def _run_boundary(name: str, root: Path) -> BoundaryResult:
    command, reason = _boundary_command(name, root)
    if command is None:
        return BoundaryResult(None, reason)
    try:
        result = subprocess.run(
            command,
            cwd=root,
            capture_output=True,
            text=True,
            timeout=BOUNDARY_TIMEOUT_SECONDS,
            check=False,
        )
    except (OSError, subprocess.SubprocessError) as error:
        return BoundaryResult(None, f"the tool failed to start: {error}")
    return BoundaryResult(result.returncode, (result.stdout + result.stderr).strip())


def check_boundaries(
    design: Design,
    repo: Repo,
    cache: dict[str, BoundaryResult],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """Run the boundary tools the design names and report failures verbatim.

    Never installs a tool. A tool that is absent is reported as not run.
    """
    findings: list[dict[str, Any]] = []
    not_run: list[dict[str, Any]] = []
    for name, line in boundary_tools(design):
        if name not in cache:
            cache[name] = _run_boundary(name, repo.root)
        outcome = cache[name]
        if outcome.code is None:
            not_run.append(
                {"tool": name, "design": design.rel, "reason": outcome.output},
            )
        elif outcome.code != 0:
            findings.append(
                finding(
                    "BOUNDARY",
                    design,
                    line,
                    f"{name} exited {outcome.code}:\n{outcome.output[-OUTPUT_LIMIT:]}",
                ),
            )
    return findings, not_run


def scan(paths: list[str], root: Path, design_dir: Path) -> Report:
    """Run every deterministic check on the designs that are marked implemented."""
    report = Report()
    repo = Repo(root, design_dir)
    cache: dict[str, BoundaryResult] = {}
    known: dict[str, str] = {}
    try:
        state = read_state(root)
        known = state["designs"] if state else {}
    except (OSError, ValueError) as error:
        # Reported rather than swallowed: every design then counts as changed.
        report.state_error = (
            f"drift state unreadable, treating all designs as changed: {error}"
        )
    for design in collect_designs(paths, design_dir, root):
        entry: dict[str, Any] = {"path": design.rel, "status": design.status or None}
        if design.status != "implemented":
            if not design.meta:
                reason = "no frontmatter"
            elif design.status == "approved":
                reason = (
                    "approved, not marked implemented "
                    "(set `status: implemented` once built)"
                )
            else:
                reason = f"status is {design.status or 'missing'}"
            entry.update(scanned=False, skip_reason=reason)
            report.designs.append(entry)
            continue
        findings = check_existence(design, repo)
        criteria, criteria_skip = check_criteria(design, repo)
        findings.extend(criteria)
        boundary, not_run = check_boundaries(design, repo, cache)
        findings.extend(boundary)
        refs = referenced_files(design, repo)
        entry.update(
            scanned=True,
            findings=len(findings),
            referenced_files=refs,
            digest=digest(refs, root),
        )
        entry["changed_since_last_pass"] = known.get(design.rel) != entry["digest"]
        if criteria_skip:
            entry["criteria_skipped"] = criteria_skip
        report.designs.append(entry)
        report.findings.extend(findings)
        report.not_run.extend(not_run)
    return report


def summary(report: Report) -> str:
    """Render the short human summary printed on stderr."""
    lines: list[str] = []
    for entry in report.designs:
        if not entry["scanned"]:
            lines.append(f"SKIPPED {entry['path']}: {entry['skip_reason']}")
        elif entry["findings"] == 0:
            lines.append(f"CLEAR   {entry['path']}")
    lines.extend(
        f"{f['kind']:<8}{f['design']}:{f['line']} {f['detail'].splitlines()[0]}"
        for f in report.findings
    )
    lines.extend(
        f"NOT RUN {n['tool']} ({n['design']}): {n['reason']}" for n in report.not_run
    )
    if report.state_error:
        lines.append(f"NOTE    {report.state_error}")
    lines.extend(
        f"NOTE    {e['path']}: criteria not mapped, {e['criteria_skipped']}"
        for e in report.designs
        if e.get("criteria_skipped")
    )
    return "\n".join(lines)


def read_state(root: Path) -> dict[str, Any] | None:
    """Read the drift state.

    Returns:
        The state, or None when the file does not exist.

    Raises:
        ValueError: If the file exists but is not a valid state file.

    """
    path = root / STATE_PATH
    if not path.is_file():
        return None
    state = json.loads(path.read_text(encoding="utf-8"))
    if (
        not isinstance(state, dict)
        or not isinstance(state.get("checked_at"), (int, float))
        or not isinstance(state.get("designs"), dict)
    ):
        msg = "drift state has the wrong shape"
        raise ValueError(msg)  # noqa: TRY004
    return state


def current_digests(root: Path, design_dir: Path) -> dict[str, str]:
    """Digest the references of every implemented design."""
    repo = Repo(root, design_dir)
    digests: dict[str, str] = {}
    for design in collect_designs([], design_dir, root):
        if design.status == "implemented":
            digests[design.rel] = digest(referenced_files(design, repo), root)
    return digests


def _recently_proposed(root: Path, now: float) -> bool:
    """Say whether the gate proposed a check within the cooldown.

    An unreadable file counts as not proposed, so a damaged cooldown file can
    only cause one extra message and never silences the gate for good.
    """
    try:
        data = json.loads((root / GATE_PATH).read_text(encoding="utf-8"))
        return now - float(data["proposed_at"]) < COOLDOWN_HOURS * 3600
    except OSError, ValueError, KeyError, TypeError:
        return False


def _note_proposal(root: Path, now: float) -> None:
    """Remember that a proposal was made, so the next startup stays quiet.

    The cooldown file is separate from the drift state, which records only
    completed passes. A failed write is ignored, because the gate must not fail.
    """
    try:
        path = root / GATE_PATH
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({"proposed_at": now}) + "\n", encoding="utf-8")
    except OSError:
        return


def gate_message(root: Path, design_dir: Path, now: float) -> str | None:
    """Decide whether a drift pass is due and return the message, or None.

    A pass is due when the last one is at least seven days old and a referenced
    file changed since. With no state, every design counts as changed. After a
    proposal the gate stays quiet for 24 hours, so it does not repeat at every
    startup before the user has run the check.
    """
    if not design_dir.is_dir():
        return None
    digests = current_digests(root, design_dir)
    if not digests:
        return None
    state = read_state(root)
    last = float(state["checked_at"]) if state else None
    if last is not None and now - last < MIN_AGE_DAYS * 86400:
        return None
    known = state["designs"] if state else {}
    changed = sorted(d for d, value in digests.items() if known.get(d) != value)
    if not changed:
        return None
    if _recently_proposed(root, now):
        return None
    since = (
        "no drift pass has run yet"
        if last is None
        else f"the last drift pass was {int((now - last) // 86400)} days ago"
    )
    return (
        f"A drift check is due for this project ({since}, and files referenced by "
        f"{len(changed)} implemented design document(s) changed: "
        f"{', '.join(changed)}). "
        "Tell the user in one line that a drift check is due and that "
        "/implement:drift-check runs it. "
        "Do not start the check or any agent yourself, and do not raise it again "
        "unless the user asks."
    )


def cmd_scan(args: argparse.Namespace) -> int:
    """Run `scan`."""
    root = Path(args.root).resolve() if args.root else find_root(Path.cwd())
    design_dir = design_dir_for(root, args.design_dir)
    try:
        report = scan(args.paths, root, design_dir)
    except (ScanError, OSError) as error:
        print(f"drift-scan: {error}", file=sys.stderr)
        return 2
    json.dump(
        {
            "root": str(root),
            "design_dir": str(design_dir),
            "designs": report.designs,
            "findings": report.findings,
            "not_run": report.not_run,
            "state_error": report.state_error,
        },
        sys.stdout,
        indent=2,
    )
    print()
    print(f"design directory: {design_dir}", file=sys.stderr)
    if not report.designs:
        print("no design documents found", file=sys.stderr)
    print(summary(report), file=sys.stderr)
    return 1 if report.findings else 0


def cmd_gate(args: argparse.Namespace) -> int:
    """Run `gate`, failing open.

    SessionStart cannot block, and a broken gate must not cost the user a
    session, so every error ends in silence. A corrupt state file is among them.
    """
    try:
        payload = json.loads(sys.stdin.read() or "{}")
        cwd = Path(payload.get("cwd") or Path.cwd())
        root = find_root(cwd)
        now = time.time()
        message = gate_message(root, design_dir_for(root, args.design_dir), now)
        if message:
            _note_proposal(root, now)
            print(
                json.dumps(
                    {
                        "hookSpecificOutput": {
                            "hookEventName": "SessionStart",
                            "additionalContext": message,
                        },
                    },
                ),
            )
    except Exception:  # noqa: BLE001
        return 0
    return 0


def ensure_ignored(root: Path) -> str:
    """Keep `.implement/` out of git without touching a tracked file.

    Returns:
        A one-line description of what was done.

    """
    probe = subprocess.run(
        ["git", "-C", str(root), "check-ignore", "-q", ".implement/x"],
        check=False,
        timeout=10,
    )
    if probe.returncode == 0:
        return ".implement/ is already ignored"
    exclude = Path(
        subprocess.run(
            ["git", "-C", str(root), "rev-parse", "--git-path", "info/exclude"],
            capture_output=True,
            text=True,
            check=True,
            timeout=10,
        ).stdout.strip(),
    )
    exclude = exclude if exclude.is_absolute() else root / exclude
    exclude.parent.mkdir(parents=True, exist_ok=True)
    with exclude.open("a", encoding="utf-8") as handle:
        handle.write(".implement/\n")
    return f"added .implement/ to {exclude}"


def cmd_ignore(args: argparse.Namespace) -> int:
    """Run `ignore`."""
    root = Path(args.root).resolve() if args.root else find_root(Path.cwd())
    try:
        print(ensure_ignored(root))
    except (OSError, subprocess.SubprocessError) as error:
        print(
            f"drift-scan: could not update .git/info/exclude: {error}",
            file=sys.stderr,
        )
        return 2
    return 0


def cmd_record(args: argparse.Namespace) -> int:
    """Run `record`."""
    root = Path(args.root).resolve() if args.root else find_root(Path.cwd())
    try:
        digests = current_digests(root, design_dir_for(root, args.design_dir))
        path = root / STATE_PATH
        path.parent.mkdir(parents=True, exist_ok=True)
        state = {
            "version": STATE_VERSION,
            "checked_at": time.time(),
            "designs": digests,
        }
        path.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
        print(f"recorded {len(digests)} design(s) in {path}")
        print(ensure_ignored(root))
    except (OSError, subprocess.SubprocessError, ScanError) as error:
        print(f"drift-scan: {error}", file=sys.stderr)
        return 2
    return 0


def main() -> int:
    """Parse the command line and dispatch."""
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n", maxsplit=1)[0])
    sub = parser.add_subparsers(dest="command", required=True)
    for name, func in (
        ("scan", cmd_scan),
        ("gate", cmd_gate),
        ("record", cmd_record),
        ("ignore", cmd_ignore),
    ):
        p = sub.add_parser(name)
        p.add_argument(
            "--root",
            help="repository root, default: the git top level of the cwd",
        )
        p.add_argument("--design-dir", help="design directory relative to the root")
        if name == "scan":
            p.add_argument("paths", nargs="*", help="design files or directories")
        p.set_defaults(func=func)
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
