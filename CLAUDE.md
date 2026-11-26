# azure-infra

Bicep for the Azure resources shared by ai-agent-service and rag-ingestion-service: Microsoft
Foundry (account, project, model deployments), Log Analytics + Application Insights, and
data-plane role assignments. Design: docs/adr/0001-bicep-for-shared-azure-resources.md.

## Rules

- Existing resources are adopted, never recreated: model quota is per subscription and region.
  Names, SKUs and capacities in `env/*.bicepparam` must match Azure.
- Always `make what-if RG=...` before `make deploy RG=... CONFIRM=yes`; read every `~` on an
  existing resource before applying.
- Incremental mode only. Never complete mode.
- No subscription ids, tenant ids, object ids or secrets in the repository. The developer's
  object id comes from the environment (`DEVELOPER_PRINCIPAL_ID`, set by the Makefile).
- API versions: newest GA (non-preview) version the Bicep CLI knows; check with
  `bicep build` (BCP081 means the version does not exist).
- `make check` (build + lint) must pass; it is what CI runs.
- Code, comments, commits and PRs in English.
