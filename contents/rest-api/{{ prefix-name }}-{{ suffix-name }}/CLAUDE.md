# {{ prefix-name }}-{{ suffix-name }}

This project was generated from [python-blank.archetype](https://github.com/p6m-archetypes/python-blank.archetype) with the **REST API** profile — a FastAPI/uvicorn HTTP service. It ships with CI/CD workflows, Kubernetes manifests, and a placeholder Dockerfile — but **no Python application code**. This file tells you (and Claude Code) exactly what to build.

## Platform constraints

The CI and Kubernetes deployment make hard assumptions. All of these must be satisfied before the first push to `main`:

| Constraint | Why |
|------------|-----|
| `pyproject.toml` must exist at repo root | `python-uv-cut-tag` reads and bumps the version on every `main` push |
| App must bind to `${SERVER_PORT:-8080}` | The deployment injects `SERVER_PORT=8080`; the readiness probe hits port 8080 |
| `/health` endpoint required | Kubernetes readiness probe path is `/health` |
| CMD must call `.venv/bin/uvicorn` directly, not `uv run` | `uv run` writes to `/root/.cache/uv` at startup — crashes with `readOnlyRootFilesystem: true` (exit code 2) |
| `[tool.pytest.ini_options] testpaths = ["tests"]` required | Without it, `pytest` discovers `test_*.py` files inside `.venv` (shipped by packages like `anyio`) and fails to spawn because pytest itself isn't on `PATH` |
| `pytest` and `httpx` in `[dependency-groups] dev` | `python-uv-build` runs `uv run pytest`; both must be installed |

## Files to create

### `pyproject.toml`

```toml
[project]
name = "{{ prefix-name }}-{{ suffix-name }}"
version = "0.0.0"
description = "TODO: describe this service"
requires-python = ">=3.11"
dependencies = [
    "fastapi>=0.115.0",
    "uvicorn[standard]>=0.32.0",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/{{ prefix_name }}_{{ suffix_name }}"]

[dependency-groups]
dev = [
    "pytest>=8.0",
    "httpx>=0.27",
]

[tool.pytest.ini_options]
testpaths = ["tests"]
```

### `Dockerfile` (replace the placeholder)

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/
COPY pyproject.toml .
COPY src/ src/
RUN uv sync --no-dev
EXPOSE 8080
CMD ["/bin/sh", "-c", "exec /app/.venv/bin/uvicorn {{ prefix_name }}_{{ suffix_name }}.main:app --host 0.0.0.0 --port ${SERVER_PORT:-8080}"]
```

### `docker-compose.yml`

`integration-tests.yml` checks health on both port 8080 and port 8000.

```yaml
services:
  {{ prefix-name }}-{{ suffix-name }}:
    build: .
    environment:
      - SERVER_PORT=8080
    ports:
      - "8080:8080"
      - "8000:8080"
```

### `src/{{ prefix_name }}_{{ suffix_name }}/__init__.py`

Empty file.

### `src/{{ prefix_name }}_{{ suffix_name }}/main.py`

```python
from fastapi import FastAPI

app = FastAPI(title="{{ prefix-name }}-{{ suffix-name }}")


@app.get("/")
def root():
    return {"service": "{{ prefix-name }}-{{ suffix-name }}", "status": "ok"}


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/health/live")
def health_live():
    return {"status": "ok"}


@app.get("/health/ready")
def health_ready():
    return {"status": "ok"}
```

### `tests/__init__.py`

Empty file.

### `tests/test_main.py`

```python
from fastapi.testclient import TestClient

from {{ prefix_name }}_{{ suffix_name }}.main import app

client = TestClient(app)


def test_root():
    response = client.get("/")
    assert response.status_code == 200


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_health_live():
    response = client.get("/health/live")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_health_ready():
    response = client.get("/health/ready")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
```

## Adding business logic

The scaffold gives you a running app with health checks and nothing else. When you (or Claude Code) add features, follow these conventions so the code stays testable and keeps the platform contract intact.

### Where code goes

Keep `main.py` thin — it just wires the app together. Put features in their own modules:

```
src/{{ prefix_name }}_{{ suffix_name }}/
  main.py          # FastAPI app, router registration, health endpoints (keep thin)
  routers/         # one APIRouter module per resource
  schemas/         # Pydantic request/response models (your validation layer)
  services/        # business logic — no FastAPI imports, so it unit-tests cleanly
```

### Adding an endpoint

1. Define request/response models in `schemas/` (Pydantic validates the input for you).
2. Put the actual logic in a `services/` function that takes and returns plain data (no `Request`/`Response`), so you can unit-test it without HTTP.
3. Add an `APIRouter` in `routers/`, call the service, return the response model.
4. Register it in `main.py`: `app.include_router(widgets.router)`.
5. Add a test with `TestClient` (same pattern as `tests/test_main.py`).

Use `async def` for routes and I/O. **Never remove or break `/health`, `/health/live`, or `/health/ready`** — the readiness probe hits `/health` and the pod will never go Ready without it.
{%- if database == "CockroachDB (platform-managed)" or database == "External (bring your own URL)" %}

### Database (wired in)

The manifest injects `DATABASE_URL` into the environment — read it with `os.environ["DATABASE_URL"]`, never hardcode it. Use async SQLAlchemy:

- Add `sqlalchemy[asyncio]>=2.0` and `asyncpg>=0.29` to `dependencies` in `pyproject.toml`.
- Create one `create_async_engine(...)` at startup; hand out an `AsyncSession` per request via a FastAPI dependency.
- Keep SQL/data access in a `repositories/` module; services call repositories, routers call services.
{%- endif %}
{%- if object_storage == "Yes" %}

### Object storage (wired in)

`AZURE_STORAGE_CONTAINER_NAME` is in the environment and the app's identity already has read/write. Use `azure-storage-blob` + `azure-identity` with `DefaultAzureCredential()` (workload identity) — **do not** put account keys or connection strings in code or config.
{%- endif %}
{%- if egress == "Restricted (allow-list)" %}

### Outbound calls are restricted

Egress is allow-listed: the app can only reach the hosts in `networking.outbound.external` in `.platform/kubernetes/base/application.yaml`. Calling any other host fails — add the host there before depending on it.
{%- endif %}

### Example prompts

With the conventions above in this file, you can ask Claude Code to:

- "Add a `POST /widgets` endpoint that validates a `WidgetCreate` body and returns the created widget." → it adds the schema, service, and router, registers the router, and writes a `TestClient` test — without touching the health endpoints.
{%- if database == "CockroachDB (platform-managed)" or database == "External (bring your own URL)" %}
- "Persist widgets in the database and add `GET /widgets/{id}`." → it adds a repository backed by an async session dependency and reads `DATABASE_URL` from the environment.
{%- endif %}

## CI pipeline

Once the files above exist, the four workflows run cleanly:

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| `build.yml` | Every push | Bumps patch version, runs `pytest`, builds multi-arch Docker image, dispatches manifest update to deploy to dev |
| `integration-tests.yml` | Push to `main`/`develop`, PRs | `uv sync && uv build`, spins up Docker Compose stack, verifies health endpoints on ports 8080 and 8000 |
| `cut-tag.yml` | Manual | Cuts a minor/major/patch release tag and creates a GitHub Release |
| `promote.yml` | Manual | Promotes a tagged release to `stg` or `prd` |

## First push checklist

- [ ] All files above created
- [ ] `pyproject.toml` version is `0.0.0` (CI will bump it)
- [ ] `Dockerfile` CMD uses `.venv/bin/uvicorn`, not `uv run uvicorn`
- [ ] `docker-compose.yml` sets `SERVER_PORT=8080` and maps both ports
- [ ] `tests/` directory exists with at least one `test_*.py`
- [ ] `[tool.pytest.ini_options] testpaths = ["tests"]` present in `pyproject.toml`
