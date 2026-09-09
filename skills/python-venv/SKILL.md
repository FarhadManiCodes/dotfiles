---
name: python-venv
description: >
  Find the Python environment a project is meant to use, instead of creating another one. Use
  when about to run python, pip, pytest or any Python tool in a project; when installing a
  package; when deciding where a new environment should live; or when an import fails that
  should have worked. Covers the three places environments live on this machine, how to tell which one a
  project intends, and which commands create one as a side effect.
---

# Where Python environments live here

There are **three** locations, and they are not interchangeable. Look for an existing
environment before making one; the usual failure is a second `.venv` beside a perfectly good
first, or an install into system Python.

| Location | What it is | Use it? |
|---|---|---|
| `<project>/.venv` | Project-local environment | Yes — the default for a standalone project |
| `$CENTRAL_VENVS/<name>` (`~/.central_venvs/<name>`) | Shared environment several projects point at | Yes — when a project's `.envrc` names one |
| `~/.local/share/uv/tools/<tool>/` | `uv tool` installs backing CLIs on `PATH` | **No** — never install project deps here |

The third is the one to be careful about: those exist so `papis`, `yt-dlp`, `basedpyright` and
friends work as commands. They are not project environments, and adding to one is a way to break
a working tool.

## Finding the intended environment

Check in this order, and stop at the first hit:

```bash
cat .envrc 2>/dev/null                                       # 1. the explicit answer
ls -d ./.venv 2>/dev/null                                    # 2. project-local
ls -1 "$CENTRAL_VENVS" 2>/dev/null                            # 3. what central holds
```

**`.envrc` is authoritative** — it is generated with the environment written into it, so it
tells you both which one and where:

```
# Auto-generated - Virtual Environment: local
source .venv/bin/activate
```

A line sourcing `.venv/bin/activate` means project-local; one sourcing
`~/.central_venvs/<name>/bin/activate` means that project deliberately shares a central
environment, and creating a local `.venv` beside it would shadow the intended one.

To enumerate every real environment on disk, look for the marker file rather than the directory
name:

```bash
find ~/projects ~/learning "$CENTRAL_VENVS" -maxdepth 3 -name pyvenv.cfg 2>/dev/null
```

The central directory being empty is a normal state, not a fault — the mechanism is live either
way, and it can fill up later. Check it rather than assuming in either direction.

## Using one, without activating

Every tool call is a separate shell, so `source .venv/bin/activate` in one call is gone by the
next — an activate-then-use sequence across two calls silently runs the wrong interpreter.

**Call the interpreter by path.** No activation needed:

```bash
.venv/bin/python -m pytest
.venv/bin/pip install <pkg>
"$CENTRAL_VENVS/<name>/bin/python" script.py
```

If you genuinely need activation, keep it inside one invocation:
`bash -c 'source .venv/bin/activate && python ...'`.

`CENTRAL_VENVS` is set in `zsh/.zshenv`, so it resolves in every shell including
non-interactive ones — it moved there on 2026-09-06 precisely so this is dependable.

Note the `vc`/`va`/`vl` shell helpers are zsh functions from `.zshrc` and do **not** exist in a
non-interactive shell (`type va` → not found). They are for a person at a prompt; the paths
above are the equivalent you can execute.

## Commands that create an environment as a side effect

**`uv run` creates `.venv` when a `pyproject.toml` is present**, plus a `uv.lock`. Verified: in
an empty directory `uv run python` creates nothing, but with a two-line `pyproject.toml` the
same command writes both. In a git repo that is a tracked-file change from what looks like a
read-only command.

So in a project you did not set up, prefer `.venv/bin/python` until you know whether an
environment is meant to exist. `uv run` is correct once it does — it resolves to the project's
`.venv`.

`uv pip install` outside any environment installs into whatever Python is on `PATH`. Check
first:

```bash
python -c "import sys; print(sys.prefix)"    # /usr means system Python — do not install
```

## Creating one, when it is genuinely needed

Only after all three locations come up empty. Then the choice of location is the decision:

- **project-local `.venv`** for a standalone project — this is what the existing projects use;
- **central** when several projects should share one environment, which is what that directory
  is for.

Say which you are creating and why before creating it. Adding a dependency also changes
`pyproject.toml` or a lockfile — those are the user's project files, so name what changed.

Jupyter is per-environment, not global: a notebook needs `ipykernel` installed in the
environment it will run against.
