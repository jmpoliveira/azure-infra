# azure-infra

Infrastructure as code (Bicep) for the Azure resources shared by
[ai-agent-service](https://github.com/jmpoliveira/ai-agent-service) and
[rag-ingestion-service](https://github.com/jmpoliveira/rag-ingestion-service):

- **Microsoft Foundry**: an AI Services account in Sweden Central, a project, and model
  deployments (`gpt-6-luna` for the agent, `text-embedding-3-small` for ingestion). They are
  **Global Standard** today, so requests may be processed outside the EU; the move to Data Zone
  Standard is planned in [ADR 0002](docs/adr/0002-model-data-residency.md).
- **Observability**: a Log Analytics workspace and a workspace-based Application Insights,
  connected to Foundry so agent traces show in the Foundry portal.
- **Access**: data-plane roles for a developer: keyless (Microsoft Entra ID) model calls and read
  access to the traces.

Why Bicep, why a separate repository, and why the existing resources are adopted instead of
recreated: [ADR 0001](docs/adr/0001-bicep-for-shared-azure-resources.md). Where the models
process data, and the plan to move to the EU data zone:
[ADR 0002](docs/adr/0002-model-data-residency.md).

## Layout

```text
infra/
  main.bicep                    resource-group deployment: wires the modules
  modules/foundry.bicep         account, project, deployments, Application Insights connection
  modules/observability.bicep   Log Analytics (with a daily cap) + Application Insights
  modules/role-assignments.bicep  roles for one principal
env/dev.bicepparam              values for the dev environment
bicepconfig.json                linter rules (secrets, unused parameters, API versions)
```

## Requirements

- Azure CLI, logged in: `az login` (in WSL, `az login --use-device-code`), on the right
  subscription (`make whoami`).
- Bicep through the Azure CLI: `make bicep` installs the pinned version. Bicep is a .NET program
  and needs the ICU library; on Ubuntu/WSL without it, every command fails with "Couldn't find a
  valid ICU package": `sudo apt-get install -y libicu-dev`.
- To deploy: Owner, or Contributor plus User Access Administrator, on the resource group (role
  assignments need the latter).

## Usage

```bash
make check                                   # build + lint, no Azure access needed
make what-if RG=<resource-group>             # preview: nothing is changed
make deploy  RG=<resource-group> CONFIRM=yes # apply
```

`what-if` first, always. Read it as a code review: `+` creates, `~` modifies, `-` deletes (there
are no deletes in incremental mode), `*` ignored, `=` no change.

## Adopting existing resources

The account and its deployments were created in the portal. To bring them under Bicep without
recreating them:

1. Copy the real values into `env/dev.bicepparam` (names, model versions, SKUs, capacities):

   ```bash
   az cognitiveservices account show -n <account> -g <rg>
   az cognitiveservices account deployment list -n <account> -g <rg>
   ```

2. Run `make what-if RG=<rg>` and change the templates or parameters until the existing account,
   project and deployments show `=` (no change) or only expected differences, such as new tags.
   Investigate every `~` on them before deploying: a changed SKU or capacity is a real change.
3. Only the new resources (Log Analytics, Application Insights, the connection, the role
   assignments) should show `+`. Then deploy.

Changes made later in the portal appear as drift in the next `what-if`. Change the templates,
not the portal.

## After the first deployment

- **Keyless model calls**: the developer has *Cognitive Services OpenAI User* on the account.
  Role assignments take a few minutes to apply.
- **Traces**: the Foundry project has an Application Insights connection; the agent's OpenTelemetry
  spans reach it through the collector in `docker-env` (configured there, not here).
- **Cost guard**: Log Analytics stops ingesting for the day after 1 GB
  (`logAnalyticsDailyQuotaGb`).

## CI

GitHub Actions builds and lints on every pull request, without Azure credentials. Deployments
are manual for now (ADR 0001).

## License

MIT
