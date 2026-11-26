# ADR 0001: Bicep for the shared Azure resources, adopted from what already exists

Status: accepted

## Context

`ai-agent-service` calls a model deployed in Microsoft Foundry (its ADR 0007), and
`rag-ingestion-service` will use an embeddings deployment on the same account. The account, its
project and four model deployments were created by hand in the portal, together with the
decisions behind them (deployment type and tokens per minute; ADR 0002 covers data residency).
The next steps need more Azure resources: Application Insights for agent traces in Foundry, and
role assignments for keyless (Microsoft Entra ID) model calls.

Creating those by hand and describing them in code later does the work twice, and leaves the
quota and data-residency decisions only in the portal.

## Decision

1. **Bicep**, the Azure-native language: no state file to store and lock (Azure Resource Manager
   is the state), day-zero support for new resource types and API versions, and `what-if` to
   preview every change.
2. **A separate repository**, like `docker-env` for the local services: the resources are shared
   by several projects and belong to none of them.
3. **Adopt, do not recreate.** The templates describe the resources that exist, with the same
   names, SKUs and capacities, and are adjusted until `az deployment group what-if` reports no
   change to them. Recreating them elsewhere is not an option: model quota is per subscription,
   region, model and deployment type, so a second `gpt-6-luna` deployment would fail for lack
   of quota.
4. **Incremental mode** (the default): resources in the group that the templates do not
   describe are left alone. Complete mode would delete them.
5. **Modules by concern**: `foundry` (account, project, deployments, Application Insights
   connection), `observability` (Log Analytics + Application Insights, with a daily ingestion
   cap), `role-assignments` (data-plane access for one principal).
6. **No identifiers committed** beyond resource names: the subscription is chosen by `az login`,
   the resource group is a `make` argument, and the developer's object id is read from the
   environment (`readEnvironmentVariable`), set by the Makefile from `az ad signed-in-user`.
7. **CI builds and lints only**, without Azure credentials. Deployments are manual (`make
   what-if`, then `make deploy CONFIRM=yes`) until a deployment pipeline is worth its setup.

## Consequences

- Quota and data-residency choices are reviewed in pull requests like code.
- Changes made in the portal show up as drift in the next `what-if`; the rule is to change the
  templates, not the portal.
- Every write under the Foundry account (project, deployments, connection) runs one at a time
  (`@batchSize(1)` plus an explicit `dependsOn` chain): the resource provider rejects a change
  while another one is in progress on the same account. The first deployment failed with
  `RequestConflict` before the chain was added; `what-if` cannot detect this, only a real deploy.
- The Application Insights connection is created at account level and shared with every project.
  It holds the Application Insights connection string, an ingestion key.
- Log Analytics has a daily cap (1 GB by default): a runaway loop cannot become a large bill,
  but telemetry stops for the rest of that day when the cap is reached.

## Alternatives considered

- **Terraform (azurerm / azapi)**: multi-cloud and widely used, but it needs a remote state
  backend and lags behind new Foundry resource types. Nothing here is multi-cloud.
- **Azure Verified Modules (AVM)**: well-tested public modules. Not used for a first version
  whose purpose is to understand each property; worth revisiting as the repository grows.
- **Azure Developer CLI (azd)**: good for app + infrastructure templates. This repository has
  no application to deploy.

## Later

- Deployment from GitHub Actions with OpenID Connect (federated credential, no stored secret),
  `what-if` on pull requests and `create` on `main`.
- `foundryDisableLocalAuth = true` once every client uses Entra ID tokens.
- Workload identities (for example a container app's managed identity) as further principals of
  the `role-assignments` module.
