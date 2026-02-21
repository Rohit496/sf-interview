# Salesforce DevOps Agent Memory

## Org Details
- Target org: `rohitdotnet75.bb85a2297fcd@agentforce.com`
- Org ID: `00Dg500000583h1EAA`

## Known Pre-Existing Test Failures
- `AccountControllerTest` - Fails with DUPLICATE_VALUE and SObject row lock errors (data-dependent, not code issues)
- `SoftDrinkOrderStatusTest` - Fails with row lock and assertion errors (pre-existing, unrelated to new deployments)
- These failures appear during RunLocalTests and are NOT caused by newly deployed code

## Deployment Notes
- Use `ignoreConflicts: true` when deploying components that may already exist in the org (e.g., fields deployed by admin agent)
- The `deploy_metadata` tool accepts `sourceDir` as an array of paths
- Custom fields that already exist show `created: false, changed: false` but still deploy successfully
- MCP `get_username` tool requires permission approval; use known username directly when possible
- CRITICAL: When deploying custom fields + test classes that use `WITH USER_MODE` SOQL, the permission set granting FLS on those fields MUST be assigned to the running user. Deploying the permission set alone is not enough -- use `assign_permission_set` after deployment. Without this, tests fail with "No such column" errors even though the fields exist in the org.
- The org alias `sf-interview` maps to `rohitdotnet75.bb85a2297fcd@agentforce.com`

## Deployment History
- 2026-02-21: Account Health Indicator feature - 7 components deployed successfully (Deploy ID: 0Afg5000004GDwgCAG)
- 2026-02-21: Account Health fields + handler + test class redeployment + permission set assignment (Deploy IDs: 0Afg5000004GDBuCAO, 0Afg5000004GFgjCAG)
