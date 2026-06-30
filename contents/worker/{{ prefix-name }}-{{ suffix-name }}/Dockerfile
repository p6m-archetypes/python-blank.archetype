# Worker profile — headless long-running process. No web server, no exposed port.
FROM python:3.11-slim
WORKDIR /app
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/
COPY pyproject.toml .
COPY src/ src/
RUN uv sync --no-dev
# No EXPOSE: this profile serves no traffic. The platform omits the readiness
# probe when none is configured, so the pod is Ready as soon as it starts.
# Call the venv's python directly — `uv run` writes to /root/.cache/uv and
# crashes under readOnlyRootFilesystem: true (exit code 2).
CMD ["/bin/sh", "-c", "exec /app/.venv/bin/python -m {{ prefix_name }}_{{ suffix_name }}"]
