// Shared Azure resources for the AI projects (ai-agent-service, rag-ingestion-service):
// Microsoft Foundry with its model deployments, observability, and data-plane role assignments.
// Deployed to one resource group, in incremental mode (resources not described here are left alone).
targetScope = 'resourceGroup'

import { modelDeployment } from 'modules/foundry.bicep'

@description('Azure region. Sweden Central keeps the account in the EU; the deployments choose the data zone.')
param location string

@description('Short environment name used in tags, for example dev.')
param environmentName string

@description('Foundry (AI Services) account name.')
param foundryAccountName string

@description('Custom subdomain of the account endpoints; usually the account name.')
param foundryCustomSubDomainName string = foundryAccountName

@description('Foundry project name.')
param foundryProjectName string

@description('True disables API keys (Entra ID only). Turn on once every client is keyless.')
param foundryDisableLocalAuth bool = false

@description('Model deployments on the account.')
param modelDeployments modelDeployment[]

@description('Log Analytics workspace name.')
param logAnalyticsName string

@description('Application Insights name.')
param appInsightsName string

@description('Daily ingestion cap for the workspace, in GB.')
param logAnalyticsDailyQuotaGb int = 1

@description('Object id of the developer who gets keyless model access and trace read access; empty skips the role assignments.')
param developerPrincipalId string = ''

var tags = {
  environment: environmentName
  'managed-by': 'bicep'
  repository: 'azure-infra'
}

module observability 'modules/observability.bicep' = {
  name: 'observability'
  params: {
    location: location
    workspaceName: logAnalyticsName
    appInsightsName: appInsightsName
    dailyQuotaGb: logAnalyticsDailyQuotaGb
    tags: tags
  }
}

module foundry 'modules/foundry.bicep' = {
  name: 'foundry'
  params: {
    location: location
    accountName: foundryAccountName
    customSubDomainName: foundryCustomSubDomainName
    disableLocalAuth: foundryDisableLocalAuth
    projectName: foundryProjectName
    deployments: modelDeployments
    appInsightsName: observability.outputs.appInsightsName
    tags: tags
  }
}

module developerAccess 'modules/role-assignments.bicep' = if (!empty(developerPrincipalId)) {
  name: 'developer-access'
  params: {
    principalId: developerPrincipalId
    principalType: 'User'
    accountName: foundry.outputs.accountName
    workspaceName: observability.outputs.workspaceName
  }
}

output foundryAccountEndpoint string = foundry.outputs.accountEndpoint
output foundryProjectName string = foundry.outputs.projectName
output modelDeploymentNames string[] = foundry.outputs.deploymentNames
output appInsightsName string = observability.outputs.appInsightsName
