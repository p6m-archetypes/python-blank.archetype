# {{ prefix-name }}-{{ suffix-name }}

This project was generated from [python-blank.archetype](https://github.com/p6m-archetypes/python-blank.archetype) with the **Background Worker** profile — a headless, long-running background process (queue consumer, scheduler, data-processing loop). It ships with CI/CD workflows, Kubernetes manifests, and a Dockerfile — but **no Python application code**. This file tells you (and Claude Code) exactly what to build.

> **Not a web service.** This profile has no HTTP server, no exposed port, and no readiness probe. The platform considers the pod Ready as soon as the process starts. If you actually need to serve HTTP traffic, regenerate with the **REST API** profile instead — don't bolt a web server onto this one.

## Platform constraints

The CI and Kubernetes deployment make hard assumptions. All of these must be satisfied before the first push to `main`:

| Constraint | Why |
|------------|-----|
| `pyproject.toml` must exist at repo root | `python-uv-cut-tag` reads and bumps the version on every `main` push |
| Entry point is `python -m {{ prefix_name }}_{{ suffix_name }}` | The shipped `Dockerfile` CMD runs the package as a module — you must provide `__main__.py` |
| The process must run until terminated | A worker that exits immediately is treated as a crash by the integration smoke test and by Kubernetes (CrashLoopBackOff) |
| Handle `SIGTERM` for graceful shutdown | Kubernetes sends SIGTERM on scale-down/rollout; drain in-flight work and exit 0 |
| CMD calls `.venv/bin/python` directly, not `uv run` | `uv run` writes to `/root/.cache/uv` at startup — crashes with `readOnlyRootFilesystem: true` (exit code 2) |
| `[tool.pytest.ini_options] testpaths = ["tests"]` required | Without it, `pytest` discovers `test_*.py` files inside `.venv` (shipped by packages like `anyio`) and fails |
| `pytest` in `[dependency-groups] dev` | `python-uv-build` runs `uv run pytest`; it must be installed |

## Files to create

### `pyproject.toml`

```toml
[project]
name = "{{ prefix-name }}-{{ suffix-name }}"
version = "0.0.0"
description = "TODO: describe this worker"
requires-python = ">=3.11"
dependencies = [
    # Add your runtime deps (queue client, db driver, etc.). No web framework needed.
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/{{ prefix_name }}_{{ suffix_name }}"]

[dependency-groups]
dev = [
    "pytest>=8.0",
]

[tool.pytest.ini_options]
testpaths = ["tests"]
```

### `src/{{ prefix_name }}_{{ suffix_name }}/__init__.py`

Empty file.

### `src/{{ prefix_name }}_{{ suffix_name }}/__main__.py`

The module entry point. Run a loop that does the work and shuts down cleanly on SIGTERM.

```python
import logging
import signal
import time

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("{{ prefix_name }}_{{ suffix_name }}")

_stop = False


def _handle_sigterm(signum, frame):
    global _stop
    log.info("received signal %s — shutting down", signum)
    _stop = True


def main() -> None:
    signal.signal(signal.SIGTERM, _handle_sigterm)
    signal.signal(signal.SIGINT, _handle_sigterm)
    log.info("{{ prefix-name }}-{{ suffix-name }} worker started")
    while not _stop:
        # TODO: poll a queue / run a batch / do the work
        time.sleep(5)
    log.info("worker stopped cleanly")


if __name__ == "__main__":
    main()
```

### `docker-compose.yml`

Used by the integration smoke test to confirm the worker starts and stays up.

```yaml
services:
  {{ prefix-name }}-{{ suffix-name }}:
    build: .
    environment:
      - LOGGING_STRUCTURED=true
```

### `tests/__init__.py`

Empty file.

### `tests/test_worker.py`

```python
import {{ prefix_name }}_{{ suffix_name }}.__main__ as worker


def test_sigterm_sets_stop_flag():
    worker._stop = False
    worker._handle_sigterm(15, None)
    assert worker._stop is True


def test_main_module_imports():
    assert hasattr(worker, "main")
```

## Adding business logic

The scaffold gives you a loop that starts, idles, and shuts down on SIGTERM. Your work goes inside that loop — but keep the loop thin and put the real logic in its own module so you can test it without running forever.

### Where code goes

```
src/{{ prefix_name }}_{{ suffix_name }}/
  __main__.py      # signal handling + the run loop (driver only — keep thin)
  processing.py    # the actual work as functions you can unit-test
```

### The work loop

`__main__.py` is the driver; `processing.py` holds the logic the loop calls. Each iteration should do one unit of work, then re-check `_stop`:

- **Queue consumer:** poll → process one message in a `try/except` → ack on success → loop. One bad message must not kill the loop — log it (or dead-letter it) and continue.
- **Polling/batch loop:** fetch a batch → process it → sleep briefly → loop.

Respect `_stop`: long operations should check it and return promptly, so a SIGTERM drains in-flight work within the grace period instead of being killed. Make processing idempotent if your source delivers at-least-once.
{%- if database == "CockroachDB (platform-managed)" or database == "External (bring your own URL)" %}

### Database (wired in)

The manifest injects `DATABASE_URL` into the environment — read it with `os.environ["DATABASE_URL"]`, never hardcode it. Open one async engine/pool at startup, reuse it across loop iterations, and dispose it on shutdown (in the SIGTERM path). Add `sqlalchemy[asyncio]>=2.0` and `asyncpg>=0.29` to `dependencies`.
{%- endif %}
{%- if object_storage == "Yes" %}

### Object storage (wired in)

`AZURE_STORAGE_CONTAINER_NAME` is in the environment and the app identity has read/write. Use `azure-storage-blob` + `azure-identity` with `DefaultAzureCredential()` — no keys or connection strings in code or config.
{%- endif %}
{%- if egress == "Restricted (allow-list)" %}

### Outbound calls are restricted

Egress is allow-listed — the worker can only reach the hosts in `networking.outbound.external` in `.platform/kubernetes/base/application.yaml`. Add any new host there before calling it.
{%- endif %}

### Guardrails

- No HTTP server, no port, no `/health` — that's the REST API profile. If you need to serve traffic, regenerate as REST API rather than bolting a server onto the loop.
- Don't `time.sleep()` so long that SIGTERM can't interrupt it — sleep in short increments or use an interruptible wait, and check `_stop` between chunks.

### Example prompts

- "Add a consumer that reads messages off the orders queue and processes each one, acking on success." → Claude puts the handler in `processing.py`, wires it into the loop with per-message error handling, and tests the handler directly.
{%- if database == "CockroachDB (platform-managed)" or database == "External (bring your own URL)" %}
- "Each cycle, pull unprocessed rows from the database in batches of 100 and mark them done." → Claude reads `DATABASE_URL`, opens an async engine at startup, and keeps the batch logic idempotent.
{%- endif %}

## CI pipeline

Once the files above exist, the four workflows run cleanly:

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| `build.yml` | Every push | Bumps patch version, runs `pytest`, builds multi-arch Docker image, dispatches manifest update to deploy to dev |
| `integration-tests.yml` | Push to `main`/`develop`, PRs | `uv sync && uv build`, starts the container via Docker Compose, asserts the worker **stays running** (no HTTP curl) |
| `cut-tag.yml` | Manual | Cuts a minor/major/patch release tag and creates a GitHub Release |
| `promote.yml` | Manual | Promotes a tagged release to `stg` or `prd` |

## First push checklist

- [ ] All files above created
- [ ] `pyproject.toml` version is `0.0.0` (CI will bump it)
- [ ] `__main__.py` runs a loop that blocks until SIGTERM (does not exit immediately)
- [ ] `Dockerfile` CMD uses `.venv/bin/python -m ...`, not `uv run`
- [ ] `tests/` directory exists with at least one `test_*.py`
- [ ] `[tool.pytest.ini_options] testpaths = ["tests"]` present in `pyproject.toml`
- [ ] Confirm you do **not** need HTTP — otherwise use the REST API profile
