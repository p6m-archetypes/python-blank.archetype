# Python Blank Archetype

![Latest Release](https://img.shields.io/github/v/release/p6m-archetypes/python-blank.archetype?style=flat-square&label=Latest%20Release&color=blue)

## Usage

To get started, [install archetect](https://github.com/p6m-archetypes/development-handbook)
and render this template to your current working directory:

```bash
archetect render git@github.com:p6m-archetypes/python-blank.archetype.git
```

This creates a completely empty Python project with only the necessary infrastructure files.

## Prompts

When rendering the archetype, you'll be prompted for the following values:

| Property       | Description                                                                                                         | Example          |
| -------------- | ------------------------------------------------------------------------------------------------------------------- | ---------------- |
| `project`      | General name that represents the service domain                                                                     | Shopping Cart    |
| `suffix`       | Used in conjunction with `project` to set package names                                                            | Service          |
| `group-prefix` | Used in conjunction with `project` to set package names                                                            | {{ group-id }}   |
| `team-name`    | Identifies the team that owns the generated project                                                                 | Growth           |

## What's Inside

This archetype provides only the essential infrastructure files:

- **GitHub Actions workflows** for CI/CD (build, promote to staging/production)
- **Kubernetes platform configuration** for deployment
- **Basic Dockerfile** for containerization
- **Project structure** with no application code
- **No dependencies, frameworks, or opinions** - completely blank slate

You add your own Python application code, dependencies, and build configuration.
