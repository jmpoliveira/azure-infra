// Microsoft Foundry: the AI Services account, one project, its model deployments and the
// Application Insights connection that turns on tracing in the Foundry portal.

@export()
@description('One model deployment. Capacity is in units of 1,000 tokens per minute (TPM).')
type modelDeployment = {
  @description('Deployment name: the value clients send as "model".')
  name: string
  model: {
    format: string
    name: string
    version: string
  }
  sku: {
    @description('For example DataZoneStandard (processing stays in the data zone) or GlobalStandard.')
    name: string
    capacity: int
  }
  raiPolicyName: string?
  versionUpgradeOption: ('NoAutoUpgrade' | 'OnceCurrentVersionExpired' | 'OnceNewDefaultVersionAvailable')?
}

@description('Azure region of the account and project.')
param location string

@description('Foundry (AI Services) account name.')
param accountName string

@description('Custom subdomain used by the endpoints; usually the account name. Cannot change after creation.')
param customSubDomainName string

@description('Account SKU.')
param accountSku string = 'S0'

@description('True disables API keys, so only Microsoft Entra ID tokens are accepted.')
param disableLocalAuth bool = false

@description('Public network access to the account.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('Foundry project name.')
param projectName string

@description('Model deployments, applied one at a time.')
param deployments modelDeployment[]

@description('Application Insights to connect for tracing; empty skips the connection.')
param appInsightsName string = ''

@description('Tags applied to every resource.')
param tags object = {}

resource account 'Microsoft.CognitiveServices/accounts@2026-09-01' = {
  name: accountName
  location: location
  tags: tags
  kind: 'AIServices'
  sku: {
    name: accountSku
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: customSubDomainName
    allowProjectManagement: true
    defaultProject: projectName
    associatedProjects: [
      projectName
    ]
    disableLocalAuth: disableLocalAuth
    publicNetworkAccess: publicNetworkAccess
    // Stated explicitly so what-if does not report them as removed. With public access enabled
    // and no IP or network rules, 'Allow' is what the portal set.
    networkAcls: {
      defaultAction: 'Allow'
    }
    // Agent 365 logging, on by default in new Foundry accounts; kept as found. Opting out is a
    // governance decision, not an infrastructure detail.
    a365LoggingEnabled: true
  }
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2026-09-01' = {
  parent: account
  name: projectName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
}

// Every write under the account runs one at a time: the resource provider rejects a change to
// a child (project, deployment, connection) while another one is in progress on the same account
// ("RequestConflict: Another operation is being performed on the parent resource"). ARM would
// otherwise run the project, the deployments and the connection in parallel, since they only
// depend on the account. Hence @batchSize(1) and the explicit dependsOn chain:
// account -> project -> deployments (one by one) -> connection.
@batchSize(1)
resource modelDeployments 'Microsoft.CognitiveServices/accounts/deployments@2026-09-01' = [
  for deployment in deployments: {
    parent: account
    name: deployment.name
    dependsOn: [
      project
    ]
    sku: deployment.sku
    properties: {
      model: deployment.model
      raiPolicyName: deployment.?raiPolicyName ?? 'Microsoft.DefaultV2'
      versionUpgradeOption: deployment.?versionUpgradeOption ?? 'OnceNewDefaultVersionAvailable'
    }
  }
]

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = if (!empty(appInsightsName)) {
  name: appInsightsName
}

// Account-level and shared with every project. Foundry reads traces through this connection;
// it stores the Application Insights connection string, which is an ingestion key, not a secret
// that grants read access.
resource appInsightsConnection 'Microsoft.CognitiveServices/accounts/connections@2026-09-01' = if (!empty(appInsightsName)) {
  parent: account
  name: 'appinsights'
  dependsOn: [
    modelDeployments
  ]
  properties: {
    category: 'AppInsights'
    target: appInsights.id
    authType: 'ApiKey'
    isSharedToAll: true
    credentials: {
      key: appInsights!.properties.ConnectionString
    }
    metadata: {
      ApiType: 'Azure'
      ResourceId: appInsights.id
    }
  }
}

output accountName string = account.name
output accountEndpoint string = account.properties.endpoint
output projectName string = project.name
output deploymentNames string[] = [for (deployment, i) in deployments: modelDeployments[i].name]
