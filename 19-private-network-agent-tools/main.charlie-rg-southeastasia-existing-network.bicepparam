using './main.bicep'

// Southeast Asia deployment example that reuses the existing Charlie agent VNet,
// the existing Alpha private endpoint subnet, and existing Alpha DNS zones.
// Recommended target deployment resource group: create a new RG, for example `charlie-foundry-rg-sea-bicep`.
//
// Important topology note:
// - `existingVnetResourceId` is the VNet used for Foundry agent network injection and MCP subnet management.
// - `existingPeSubnetResourceId` is the subnet used for private endpoint NIC creation.
// - The PE subnet may be in a separate VNet when you provide its full ARM resource ID.

// -----------------------------------------------------------------------------
// Foundry account and project
// -----------------------------------------------------------------------------
param location = 'southeastasia'
param aiServices = 'cfndrysea'
param firstProjectName = 'project'
param projectDescription = 'A project for validating Azure AI Foundry private VNet deployment in Southeast Asia with existing network and DNS zones'
param displayName = 'charlie network secured agent project southeastasia existing network'
param resourceTags = {
  SecurityControl: 'Ignore'
}

// Assign Foundry Project Manager to the current signed-in user at both scopes:
// - Account: cfndryseaaxw4
// - Project: cfndryseaaxw4/projectaxw4
param foundryProjectManagerPrincipalId = '913927c9-20b8-416c-90ce-1141e04a9cca'
param foundryProjectManagerPrincipalType = 'User'

// This adopts the existing manual project-scope assignment so future Bicep redeploys
// do not collide with the assignment that was already created from the CLI.
param foundryProjectManagerProjectRoleAssignmentName = '83cb9de4-2833-4901-96cf-43b10484520e'

// Keep generated names stable across validate, what-if, and create runs.
param deploymentTimestamp = '20260609020000'

// -----------------------------------------------------------------------------
// Model deployment
// -----------------------------------------------------------------------------
param modelName = 'gpt-4.1'
param modelFormat = 'OpenAI'
param modelVersion = '2025-04-14'
param modelSkuName = 'GlobalStandard'
param modelCapacity = 1

// -----------------------------------------------------------------------------
// Existing Southeast Asia VNet and subnets
// -----------------------------------------------------------------------------
param vnetName = 'charlie-foundry-vnet'
param agentSubnetName = 'snet-agent-services-foundry2'
param peSubnetName = 'snet-private-endpoints'
param mcpSubnetName = 'snet-mcp'

// Ignored for the existing VNet itself. The subnet prefixes are used only when the
// matching existing subnet resource ID is left empty and the template must create it.
param vnetAddressPrefix = ''
param agentSubnetPrefix = '172.17.0.0/27'
param peSubnetPrefix = ''
param mcpSubnetPrefix = '172.17.3.0/24'

param existingVnetResourceId = '/subscriptions/27b58ab1-f52c-498e-a03d-255b76c80a00/resourceGroups/charlie-foundry-rg/providers/Microsoft.Network/virtualNetworks/charlie-foundry-vnet'
param existingAgentSubnetResourceId = '/subscriptions/27b58ab1-f52c-498e-a03d-255b76c80a00/resourceGroups/charlie-foundry-rg/providers/Microsoft.Network/virtualNetworks/charlie-foundry-vnet/subnets/snet-agent-services-foundry2'

// Private endpoints will be created in the existing Alpha PE subnet.
param existingPeSubnetResourceId = '/subscriptions/27b58ab1-f52c-498e-a03d-255b76c80a00/resourceGroups/alpha-azvm-rg/providers/Microsoft.Network/virtualNetworks/alpha-azvm-vnet/subnets/snet-private-endpoints'

// Leave empty to let the template create the MCP subnet in `charlie-foundry-vnet`.
param existingMcpSubnetResourceId = ''

// -----------------------------------------------------------------------------
// Backing resources
// -----------------------------------------------------------------------------
// Leave empty to create fresh AI Search, Storage, and Cosmos DB resources in the
// target deployment resource group while reusing existing VNets and DNS zones.
param existingAiSearchResourceId = ''
param existingAzureStorageAccountResourceId = ''
param existingAzureCosmosDBAccountResourceId = ''
param existingFabricWorkspaceResourceId = ''

// -----------------------------------------------------------------------------
// Existing private DNS zones
// -----------------------------------------------------------------------------
// Existing zones are referenced from `alpha-foundry-rg`, where they are already
// linked to `alpha-azvm-vnet` for private endpoint DNS resolution.
param existingDnsZones = {
  'privatelink.services.ai.azure.com': { subscriptionId: '', resourceGroup: 'alpha-foundry-rg' }
  'privatelink.openai.azure.com': { subscriptionId: '', resourceGroup: 'alpha-foundry-rg' }
  'privatelink.cognitiveservices.azure.com': { subscriptionId: '', resourceGroup: 'alpha-foundry-rg' }
  'privatelink.search.windows.net': { subscriptionId: '', resourceGroup: 'alpha-foundry-rg' }
  'privatelink.blob.core.windows.net': { subscriptionId: '', resourceGroup: 'alpha-foundry-rg' }
  'privatelink.documents.azure.com': { subscriptionId: '', resourceGroup: 'alpha-foundry-rg' }
  'privatelink.fabric.microsoft.com': { subscriptionId: '', resourceGroup: '' }
}
