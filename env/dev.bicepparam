// Development environment. Names and SKUs match the resources created in the portal, so that
// `make what-if` reports no changes to them (README, "Adopting existing resources").
using '../infra/main.bicep'

param location = 'swedencentral'
param environmentName = 'dev'

param foundryAccountName = 'jorgepratesoliveira-259-resource'
param foundryProjectName = 'jorgepratesoliveira-2594'

// Capacity is in units of 1,000 tokens per minute (TPM).
// All four are GlobalStandard: requests may be processed in any Azure region. Moving to
// DataZoneStandard (EU processing) needs Data Zone quota and new deployments; see ADR 0002.
param modelDeployments = [
  {
    // ai-agent-service default model (agent ADR 0007, E5 baseline)
    name: 'gpt-6-luna'
    model: {
      format: 'OpenAI'
      name: 'gpt-6-luna'
      version: '2026-09-22'
    }
    sku: {
      name: 'GlobalStandard'
      capacity: 125
    }
  }
  {
    // rag-ingestion-service embeddings (planned E3)
    name: 'text-embedding-3-small'
    model: {
      format: 'OpenAI'
      name: 'text-embedding-3-small'
      version: '1'
    }
    sku: {
      name: 'GlobalStandard'
      capacity: 500
    }
  }
  {
    // Not used by any repository yet: kept as found, to decide in a later change.
    name: 'gpt-5.2'
    model: {
      format: 'OpenAI'
      name: 'gpt-5.2'
      version: '2025-12-11'
    }
    sku: {
      name: 'GlobalStandard'
      capacity: 125
    }
  }
  {
    // Not used by any repository yet: kept as found, to decide in a later change.
    name: 'gpt-5'
    model: {
      format: 'OpenAI'
      name: 'gpt-5'
      version: '2025-08-07'
    }
    sku: {
      name: 'GlobalStandard'
      capacity: 125
    }
  }
]

param logAnalyticsName = 'log-ai-dev-swc'
param appInsightsName = 'appi-ai-dev-swc'

// Read from the environment so no personal id is committed; the Makefile sets it from
// `az ad signed-in-user show`. Empty skips the role assignments.
param developerPrincipalId = readEnvironmentVariable('DEVELOPER_PRINCIPAL_ID', '')
