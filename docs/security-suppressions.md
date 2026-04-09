# Security suppressions

Every `--ignore-vuln` / `tfsec:ignore` / similar suppression used in this
repo is tracked here. Remove the entry once upstream ships a fix.

## Active

### CVE-2025-62727 (starlette)

- Package: `starlette` (transitive from `fastapi`)
- Fix version: `starlette >= 0.49.1`
- Reason: `fastapi 0.118.0` pins `starlette < 0.48`. No fastapi release
  yet allows the fixed version.
- Compensating controls:
  - `security.yml` re-runs pip-audit weekly, will catch a fastapi release
    that permits the fix
  - Trivy image scan on every PR and deploy
  - Dependabot (Phase 7) will open a PR automatically once available
- Suppressed in: `Makefile`, `.github/workflows/pr.yml`,
  `.github/workflows/security.yml`
- Added: 2026-04-09
- Review by: 2026-05-09

## Adding a new suppression

1. Confirm the finding is real
2. Confirm no safe upgrade path
3. Name a compensating control
4. Add an entry here with owner and review date
5. Add the ignore flag in all relevant places
