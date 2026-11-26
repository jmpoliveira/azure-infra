// Log Analytics workspace + workspace-based Application Insights.
// Foundry reads agent traces from this Application Insights resource (ADR 0001).

@description('Azure region for both resources.')
param location string

@description('Log Analytics workspace name.')
param workspaceName string

@description('Application Insights name.')
param appInsightsName string

@description('Days of data kept by the workspace. 30 is included in the ingestion price.')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

@description('Daily ingestion cap in GB; ingestion stops for the day when reached. -1 means no cap.')
param dailyQuotaGb int = 1

@description('Tags applied to every resource.')
param tags object = {}

resource workspace 'Microsoft.OperationalInsights/workspaces@2025-07-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    // A hard cap is the simplest cost guard for a learning environment: a runaway eval loop
    // cannot turn into a large bill, at the price of losing telemetry for the rest of the day.
    workspaceCapping: {
      dailyQuotaGb: dailyQuotaGb
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspace.id
    IngestionMode: 'LogAnalytics'
  }
}

output workspaceName string = workspace.name
output appInsightsName string = appInsights.name
output appInsightsId string = appInsights.id
