// Data-plane access for one principal (a developer or, later, a workload identity):
// keyless model calls on the Foundry account and read access to the traces.

@description('Object id of the user, group or service principal.')
param principalId string

@description('Kind of principal; setting it avoids replication delays for new principals.')
@allowed([
  'User'
  'Group'
  'ServicePrincipal'
])
param principalType string = 'User'

@description('Foundry account the principal calls with Entra ID tokens.')
param accountName string

@description('Log Analytics workspace that stores the traces.')
param workspaceName string

// Built-in role ids are the same in every tenant. Check with:
//   az role definition list --name "<role name>" --query "[].name" -o tsv
var roles = {
  // Inference calls to OpenAI models with an Entra ID token (keyless). No key access.
  cognitiveServicesOpenAiUser: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
  // Read the traces Foundry shows from Application Insights / Log Analytics.
  logAnalyticsReader: '73c42c96-874c-492b-b04d-ab87d138a893'
}

resource account 'Microsoft.CognitiveServices/accounts@2026-09-01' existing = {
  name: accountName
}

resource workspace 'Microsoft.OperationalInsights/workspaces@2025-07-01' existing = {
  name: workspaceName
}

resource openAiUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  // Deterministic name: re-deploying finds the same assignment instead of failing on a duplicate.
  name: guid(account.id, principalId, roles.cognitiveServicesOpenAiUser)
  scope: account
  properties: {
    principalId: principalId
    principalType: principalType
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      roles.cognitiveServicesOpenAiUser
    )
  }
}

resource tracesReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(workspace.id, principalId, roles.logAnalyticsReader)
  scope: workspace
  properties: {
    principalId: principalId
    principalType: principalType
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.logAnalyticsReader)
  }
}
