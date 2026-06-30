# Scheduled Task profile - runs to completion (no long-running server, no port).
FROM python:3.11-slim
WORKDIR /app
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/
COPY pyproject.toml .
COPY src/ src/
RUN uv sync --no-dev
# The platform CronJob invokes this on schedule; the process does its work and exits 0.
# Call the venv's python directly — `uv run` writes to /root/.cache/uv and crashes
# under readOnlyRootFilesystem: true (exit code 2).
CMD ["/bin/sh", "-c", "exec /app/.venv/bin/python -m {{ prefix_name }}_{{ suffix_name }}"]
