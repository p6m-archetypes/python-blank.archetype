# REST API profile — FastAPI served by uvicorn.
FROM python:3.11-slim
WORKDIR /app
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/
COPY pyproject.toml .
COPY src/ src/
RUN uv sync --no-dev
EXPOSE 8080
# Call the venv's uvicorn directly. `uv run` writes to /root/.cache/uv at startup
# and crashes under readOnlyRootFilesystem: true (exit code 2).
CMD ["/bin/sh", "-c", "exec /app/.venv/bin/uvicorn {{ prefix_name }}_{{ suffix_name }}.main:app --host 0.0.0.0 --port ${SERVER_PORT:-8080}"]
