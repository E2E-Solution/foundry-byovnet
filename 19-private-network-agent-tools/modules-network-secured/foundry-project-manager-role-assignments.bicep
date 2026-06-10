@description('Name of the Azure AI Services account that backs the Foundry account.')
param accountName string

@description('Name of the Azure AI Foundry project under the account.')
param projectName string

@description('Object ID of the Microsoft Entra principal to receive Foundry Project Manager.')
param principalId string

@description('Microsoft Entra principal type for the role assignment.')
@allowed([
  'User'
  'Group'
  'ServicePrincipal'
  'ForeignGroup'
  'Device'
])
param principalType string = 'User'

@description('Optional role assignment resource name for the account-scope assignment. Leave empty to use a deterministic GUID.')
param accountRoleAssignmentName string = ''

@description('Optional role assignment resource name for the project-scope assignment. Leave empty to use a deterministic GUID.')
param projectRoleAssignmentName string = ''

var foundryProjectManagerRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'eadc314b-1a2d-4efa-be10-5d325db5065e')

resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: accountName
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' existing = {
  parent: account
  name: projectName
}

resource foundryProjectManagerAccountAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: account
  name: empty(accountRoleAssignmentName) ? guid(principalId, foundryProjectManagerRoleDefinitionId, account.id) : accountRoleAssignmentName
  properties: {
    principalId: principalId
    roleDefinitionId: foundryProjectManagerRoleDefinitionId
    principalType: principalType
  }
}

resource foundryProjectManagerProjectAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: project
  name: empty(projectRoleAssignmentName) ? guid(principalId, foundryProjectManagerRoleDefinitionId, project.id) : projectRoleAssignmentName
  properties: {
    principalId: principalId
    roleDefinitionId: foundryProjectManagerRoleDefinitionId
    principalType: principalType
  }
}

output accountRoleAssignmentId string = foundryProjectManagerAccountAssignment.id
output projectRoleAssignmentId string = foundryProjectManagerProjectAssignment.id
