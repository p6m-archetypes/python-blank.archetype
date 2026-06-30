# {{ prefix-name }}-{{ suffix-name }}

This project was generated from [python-blank.archetype](https://github.com/p6m-archetypes/python-blank.archetype) with the **Scheduled Task** profile — a run-to-completion job (ETL, batch, scheduled report) deployed as a `PlatformTask` on a cron schedule. It ships with CI/CD workflows, a `PlatformTask` manifest, and a Dockerfile — but **no Python application code**. This file tells you (and Claude Code) exactly what to build.

> **Not a service.** No HTTP server, no port, no readiness probe. The platform runs this as a CronJob on the schedule in `.platform/kubernetes/base/application.yaml` (`spec.schedule`). The process must **do its work and exit 0** — exiting non-zero marks the run failed.

## Platform constraints

| Constraint | Why |
|------------|-----|
| `pyproject.toml` must exist at repo root | `python-uv-cut-tag` reads and bumps the version on every `main` push |
| Entry point is `python -m {{ prefix_name }}_{{ suffix_name }}` | The shipped `Dockerfile` CMD runs the package as a module — provide `__main__.py` |
| The process must run to completion and exit 0 | The CronJob treats non-zero exit as a failed run; the smoke test asserts exit 0 |
| Make the work idempotent | A schedule can fire late, overlap, or retry — a run must be safe to repeat |
| CMD calls `.venv/bin/python` directly, not `uv run` | `uv run` writes to `/root/.cache/uv` at startup — crashes with `readOnlyRootFilesystem: true` (exit code 2) |
| `[tool.pytest.ini_options] testpaths = ["tests"]` required | Without it, `pytest` discovers `test_*.py` files inside `.venv` and fails |
| `pytest` in `[dependency-groups] dev` | `python-uv-build` runs `uv run pytest`; it must be installed |

To change when the job runs, edit `spec.schedule` (cron, UTC) in the manifest. To run more often in dev, edit `.platform/kubernetes/dev/application_patch.yaml`.

## Files to create

### `pyproject.toml`

```toml
[project]
name = "{{ prefix-name }}-{{ suffix-name }}"
version = "0.0.0"
description = "TODO: describe this task"
requires-python = ">=3.11"
dependencies = [
    # Add your runtime deps (db driver, cloud SDK, etc.). No web framework needed.
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/{{ prefix_name }}_{{ suffix_name }}"]

[dependency-groups]
dev = ["pytest>=8.0"]

[tool.pytest.ini_options]
testpaths = ["tests"]
```

### `src/{{ prefix_name }}_{{ suffix_name }}/__init__.py`

Empty file.

### `src/{{ prefix_name }}_{{ suffix_name }}/__main__.py`

```python
import logging
import sys

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("{{ prefix_name }}_{{ suffix_name }}")


def run() -> None:
    log.info("{{ prefix-name }}-{{ suffix-name }} task starting")
    # TODO: do the work — extract/transform/load, generate a report, etc.
    log.info("task finished")


if __name__ == "__main__":
    try:
        run()
    except Exception:
        log.exception("task failed")
        sys.exit(1)
```

### `docker-compose.yml`

Used by the smoke test to run the task once (`docker compose run --rm`).

```yaml
services:
  {{ prefix-name }}-{{ suffix-name }}:
    build: .
    environment:
      - LOGGING_STRUCTURED=true
```

### `tests/__init__.py`

Empty file.

### `tests/test_task.py`

```python
import {{ prefix_name }}_{{ suffix_name }}.__main__ as task


def test_run_completes():
    task.run()  # should not raise
```

## Adding business logic

The scaffold gives you a `run()` that logs and exits 0. Your work goes inside `run()` — but keep `__main__.py` thin and put the steps in their own module so you can test them.

### Where code goes

```
src/{{ prefix_name }}_{{ suffix_name }}/
  __main__.py      # entry point: calls run(), maps exceptions to exit code (keep thin)
  steps.py         # the work as functions run() orchestrates
```

### Writing the task

- `run()` orchestrates; each unit of work is a function in `steps.py`.
- **Exit code is the result.** Exit 0 = success; any non-zero exit marks the CronJob run failed (and alerts fire). Let real errors propagate to the `__main__` handler that exits 1 — don't catch-and-swallow, then exit 0.
- **Idempotency is mandatory.** A schedule can fire late, overlap a previous run, or be retried. Guard with a watermark/checkpoint, upsert instead of blind insert, or an "already processed" marker — a re-run must be safe.
- **Bound the work.** A task runs to completion and exits; it must not loop forever (that's the Background Worker profile).
- Log start, record counts, and finish — `LOGGING_STRUCTURED=true` is already set, so these become structured logs you can query.

### Changing the schedule

The cron lives in `spec.schedule` (UTC) in `.platform/kubernetes/base/application.yaml`. Change cadence there, not in code; use `.platform/kubernetes/dev/application_patch.yaml` to run more often in dev.

### Need a datastore?

The Scheduled Task profile isn't prompted for a database or object storage. If your task needs one, add the resource to `.platform/kubernetes/base/application.yaml` (mirror the `resources.crdb` / `blobstorage` block the REST API profile uses) and read its connection info from the environment — never hardcode credentials.

### Example prompts

- "Add an ETL step that pulls yesterday's orders and writes a daily summary row." → Claude adds the step to `steps.py`, calls it from `run()`, and lets failures exit non-zero.
- "Make the run idempotent by checkpointing the last processed date." → Claude adds a watermark check so a re-run skips already-processed data.

## CI pipeline

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| `build.yml` | Every push | Bumps patch version, runs `pytest`, builds multi-arch Docker image, dispatches manifest update |
| `integration-tests.yml` | Push to `main`/`develop`, PRs | `uv sync && uv build`, runs the task once and asserts it **exits 0** |
| `cut-tag.yml` | Manual | Cuts a release tag and creates a GitHub Release |
| `promote.yml` | Manual | Promotes a tagged release to `stg` or `prd` |

## First push checklist

- [ ] All files above created
- [ ] `pyproject.toml` version is `0.0.0` (CI will bump it)
- [ ] `__main__.py` does the work and exits 0 (non-zero = failed run)
- [ ] Work is idempotent (safe to retry / overlap)
- [ ] `Dockerfile` CMD uses `.venv/bin/python -m ...`, not `uv run`
- [ ] `spec.schedule` in the manifest is the cron you want (UTC)
- [ ] `[tool.pytest.ini_options] testpaths = ["tests"]` present in `pyproject.toml`
