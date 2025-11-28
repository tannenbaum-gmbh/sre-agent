// Main Bicep deployment for SRE Agent Demo
// Deploys App Service, Chaos Studio, and supporting infrastructure

targetScope = 'subscription'

@description('Required. Name prefix for all resources.')
@minLength(3)
@maxLength(10)
param namePrefix string

@description('Required. Azure region for deployment.')
param location string

@description('Optional. Name of the resource group.')
param resourceGroupName string = 'rg-${namePrefix}-sre-agent'

@description('Optional. Tags to apply to all resources.')
param tags object = {}

@description('Optional. The SKU name for the App Service Plan.')
@allowed([
  'F1'
  'B1'
  'B2'
  'B3'
  'S1'
  'S2'
  'S3'
  'P1v3'
  'P2v3'
  'P3v3'
])
param appServiceSkuName string = 'S1'

@description('Optional. The runtime stack for the web app.')
@allowed([
  'DOTNETCORE|9.0'
  'DOTNETCORE|8.0'
  'NODE|20-lts'
  'NODE|18-lts'
  'PYTHON|3.12'
  'PYTHON|3.11'
])
param runtimeStack string = 'DOTNETCORE|9.0'

@description('Optional. External Git repository URL for deployment.')
param externalGitRepoUrl string = 'https://github.com/Azure-Samples/app-service-dotnet-agent-tutorial'

@description('Optional. Branch of the external Git repository.')
param externalGitBranch string = 'main'

@description('Optional. Enable Application Insights.')
param enableApplicationInsights bool = true

@description('Optional. Enable Chaos Studio experiment.')
param enableChaosStudio bool = true

@description('Optional. Duration of the chaos experiment (ISO 8601 format).')
param chaosExperimentDuration string = 'PT10M'

@description('Optional. Deploy Log Analytics workspace for monitoring.')
param deployLogAnalytics bool = true

// Variables
var logAnalyticsName = 'log-${namePrefix}'

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: union(tags, {
    'sre-agent-demo': 'true'
    'deployed-by': 'bicep'
  })
}

// Log Analytics Workspace (for Application Insights and diagnostics)
module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.9.1' = if (deployLogAnalytics) {
  scope: rg
  name: '${uniqueString(deployment().name, location)}-law'
  params: {
    name: logAnalyticsName
    location: location
    tags: tags
    skuName: 'PerGB2018'
    dataRetention: 30
  }
}

// App Service Module
module appService 'modules/app-service.bicep' = {
  scope: rg
  name: '${uniqueString(deployment().name, location)}-appservice'
  params: {
    namePrefix: namePrefix
    location: location
    tags: tags
    skuName: appServiceSkuName
    runtimeStack: runtimeStack
    externalGitRepoUrl: externalGitRepoUrl
    externalGitBranch: externalGitBranch
    enableApplicationInsights: enableApplicationInsights
    logAnalyticsWorkspaceId: deployLogAnalytics ? logAnalytics!.outputs.resourceId : ''
  }
}

// Chaos Studio Module
module chaosStudio 'modules/chaos-studio.bicep' = {
  scope: rg
  name: '${uniqueString(deployment().name, location)}-chaos'
  params: {
    namePrefix: namePrefix
    location: location
    tags: tags
    appServiceResourceId: appService.outputs.webAppId
    enableChaosStudio: enableChaosStudio
    experimentDuration: chaosExperimentDuration
  }
}

// Outputs
@description('The name of the resource group.')
output resourceGroupName string = rg.name

@description('The resource ID of the resource group.')
output resourceGroupId string = rg.id

@description('The name of the Web App.')
output webAppName string = appService.outputs.webAppName

@description('The URL of the Web App.')
output webAppUrl string = appService.outputs.webAppUrl

@description('The resource ID of the Web App.')
output webAppResourceId string = appService.outputs.webAppId

@description('The name of the App Service Plan.')
output appServicePlanName string = appService.outputs.appServicePlanName

@description('The resource ID of the Chaos Studio experiment.')
output chaosExperimentId string = enableChaosStudio ? chaosStudio.outputs.experimentId : ''

@description('The name of the Chaos Studio experiment.')
output chaosExperimentName string = enableChaosStudio ? chaosStudio.outputs.experimentName : ''

@description('The resource ID of the Log Analytics workspace.')
output logAnalyticsWorkspaceId string = deployLogAnalytics ? logAnalytics!.outputs.resourceId : ''

@description('Instructions for SRE Agent setup.')
output sreAgentInstructions string = '''
=== SRE Agent Setup Instructions ===
SRE Agent is currently in Preview and must be set up via the Azure Portal.

1. Navigate to the Azure Portal: https://portal.azure.com
2. Search for "Azure SRE Agent" in the search bar
3. Select "+ Create" to create a new agent
4. Configure the agent:
   - Subscription: Your subscription
   - Resource Group: Create a new one (e.g., rg-sre-agent)
   - Name: my-sre-agent
   - Region: East US 2 (or available region)
5. Select "Select resource groups" and choose the resource group containing your App Service
6. Click "Create"

After creation, you can:
- Chat with your agent to monitor the App Service
- Use the "broken" deployment slot to simulate failures
- Let the agent diagnose and remediate issues

For more details, see: https://learn.microsoft.com/en-us/azure/sre-agent/troubleshoot-azure-app-service
'''
