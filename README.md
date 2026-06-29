# Python Blank Archetype

![Latest Release](https://img.shields.io/github/v/release/p6m-archetypes/python-blank.archetype?style=flat-square&label=Latest%20Release&color=blue)

## Usage

[Install archetect](https://github.com/p6m-archetypes/development-handbook), then render this template into your current working directory:

```bash
archetect render git@github.com:p6m-archetypes/python-blank.archetype.git
```

## Prompts

You'll be asked for five values. Use the examples below for a service named `python-fast-api` under the `p6m-archetypes` GitHub org:

| Prompt | Description | Example |
|--------|-------------|---------|
| **Project Author** | Your name and email | `Jane Smith <jane@example.com>` |
| **Org Name** | GitHub org prefix (before the `-`) | `p6m` |
| **Solution Name** | GitHub org suffix (after the `-`) | `archetypes` |
| **Project Prefix** | Business domain or technology prefix | `python-fast` |
| **Project Suffix** | Project type | `api` |

With the example values above, the rendered project is named `python-fast-api` and the target GitHub org is `p6m-archetypes`.

## What's Inside

The archetype generates only infrastructure scaffolding — no application code. You write the Python source yourself.

| File / Directory | Purpose |
|-----------------|---------|
| `.github/workflows/build.yml` | Bump patch version, run tests, build multi-arch Docker image, dispatch manifest update to dev |
| `.github/workflows/integration-tests.yml` | `uv sync && uv build`, spin up Docker Compose stack, verify health endpoints |
| `.github/workflows/cut-tag.yml` | Manual minor/major/patch release cut and GitHub Release creation |
| `.github/workflows/promote.yml` | Promote a tagged release to `stg` or `prd` |
| `Dockerfile` | Placeholder — replace with your app image |
| `CLAUDE.md` | Onboarding guide for Claude Code: platform constraints, files to create, and first-push checklist |
