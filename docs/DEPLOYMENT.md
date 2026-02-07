# Deployment Guide

This guide explains how to deploy the Ferrufi documentation website to GitHub Pages.

## Local Build

To build the site locally for testing:

```bash
cd docs
bun install
bun run build
```

The static files will be generated in the `docs/build` directory.

## Deploying to GitHub Pages

The site is configured to be hosted at `https://mufi-lang.github.io/Ferrufi/`.

### Automatic Deployment (GitHub Actions)

We use a GitHub Action to automatically build and deploy the site when changes are pushed to the `main` branch.

The workflow file is located at `.github/workflows/deploy-docs.yml`.

**Note:** To use this workflow, you must go to your GitHub Repository Settings -> Pages and set the **Source** to "GitHub Actions".

### Manual Build & Preview

The deployment configuration is managed in `docs/docusaurus.config.ts`:

- `url`: `https://mufi-lang.github.io`
- `baseUrl`: `/Ferrufi/`
- `organizationName`: `Mufi-Lang`
- `projectName`: `Ferrufi`
- `deploymentBranch`: `gh-pages` (default)
