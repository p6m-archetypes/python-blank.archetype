# {{ PrefixName }} {{ SuffixName }}

**// TODO:** Add description of your project's business function.

Generated from the [Python Blank Archetype](https://github.com/p6m-archetypes/python-blank.archetype).

## What You Get

This project contains only the essential infrastructure files:

- **GitHub Actions workflows** for CI/CD pipeline
- **Kubernetes platform configuration** for deployment
- **Basic Dockerfile** for containerization
- **Project structure** with gitignore and dockerignore

## What You Need to Add

This is a completely blank Python project. You'll need to add:

- Your Python application code
- Dependencies (e.g., `requirements.txt`, `pyproject.toml`)
- Tests
- Application entry point
- Any framework-specific files

## Infrastructure Included

### GitHub Actions
- `build.yml` - Build and deploy to development
- `promote-stg.yml` - Promote to staging environment  
- `promote-prd.yml` - Promote to production environment
- `cut-tag.yml` - Cut release tags

### Kubernetes Platform
- `application.yaml` - Platform application configuration

### Docker
- Basic `Dockerfile` ready for your application

## Getting Started

1. Add your Python application code
2. Create your dependencies file (`requirements.txt` or `pyproject.toml`)
3. Update the Dockerfile with your application entry point
4. Update the GitHub Actions workflows to match your build process
5. Configure your deployment settings

## Contributions

**// TODO:** Add description of how you would like issues to be reported and people to reach out.
