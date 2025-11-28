// App Service Module
// Deploys an App Service Plan and Web App with deployment slot for SRE Agent monitoring

@description('Required. Name prefix for resources.')
param namePrefix string

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Optional. Tags for all resources.')
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
param skuName string = 'S1'

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
param externalGitRepoUrl string = 'https://github.com/tannenbaum-gmbh/sre-agent'

@description('Optional. Branch of the external Git repository.')
param externalGitBranch string = 'main'

@description('Optional. Path to the application source code within the repository.')
param appSourcePath string = 'src/SreAgentDemo'

@description('Optional. Enable Application Insights.')
param enableApplicationInsights bool = true

@description('Optional. Log Analytics Workspace resource ID for diagnostics.')
param logAnalyticsWorkspaceId string = ''

// Variables
var appServicePlanName = 'asp-${namePrefix}'
var webAppName = 'app-${namePrefix}'
var appInsightsName = 'appi-${namePrefix}'
var isLinux = contains(runtimeStack, 'NODE') || contains(runtimeStack, 'PYTHON')

// App Service Plan using AVM module
module appServicePlan 'br/public:avm/res/web/serverfarm:0.4.1' = {
  name: '${uniqueString(deployment().name, location)}-asp'
  params: {
    name: appServicePlanName
    location: location
    tags: tags
    skuName: skuName
    skuCapacity: 1
    kind: isLinux ? 'linux' : 'app'
    reserved: isLinux
    diagnosticSettings: !empty(logAnalyticsWorkspaceId)
      ? [
          {
            workspaceResourceId: logAnalyticsWorkspaceId
            metricCategories: [
              {
                category: 'AllMetrics'
              }
            ]
          }
        ]
      : []
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = if (enableApplicationInsights) {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: !empty(logAnalyticsWorkspaceId) ? logAnalyticsWorkspaceId : null
  }
}

// Web App using AVM module
module webApp 'br/public:avm/res/web/site:0.13.3' = {
  name: '${uniqueString(deployment().name, location)}-webapp'
  params: {
    name: webAppName
    location: location
    tags: tags
    kind: isLinux ? 'app,linux' : 'app'
    serverFarmResourceId: appServicePlan.outputs.resourceId
    httpsOnly: true
    publicNetworkAccess: 'Enabled'
    siteConfig: {
      linuxFxVersion: isLinux ? runtimeStack : null
      netFrameworkVersion: !isLinux && contains(runtimeStack, 'DOTNETCORE') ? 'v9.0' : null
      alwaysOn: skuName != 'F1' // Always On not supported on Free tier
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
    }
    appInsightResourceId: enableApplicationInsights ? appInsights.id : null
    // Enable managed identity on the main web app
    managedIdentities: {
      systemAssigned: true
    }
    // Deployment slots (only supported on Standard tier and above)
    slots: contains(['F1', 'B1', 'B2', 'B3'], skuName)
      ? []
      : [
          {
            name: 'broken'
            managedIdentities: {
              systemAssigned: true
            }
            siteConfig: {
              linuxFxVersion: isLinux ? runtimeStack : null
              netFrameworkVersion: !isLinux && contains(runtimeStack, 'DOTNETCORE') ? 'v9.0' : null
              alwaysOn: true
              ftpsState: 'Disabled'
              minTlsVersion: '1.2'
              http20Enabled: true
            }
          }
        ]
    basicPublishingCredentialsPolicies: [
      {
        name: 'ftp'
        allow: false
      }
      {
        name: 'scm'
        allow: true // Required for External Git deployment
      }
    ]
    diagnosticSettings: !empty(logAnalyticsWorkspaceId)
      ? [
          {
            workspaceResourceId: logAnalyticsWorkspaceId
            logCategoriesAndGroups: [
              {
                categoryGroup: 'allLogs'
              }
            ]
            metricCategories: [
              {
                category: 'AllMetrics'
              }
            ]
          }
        ]
      : []
  }
}

// Configure External Git deployment for main slot
resource webAppSourceControl 'Microsoft.Web/sites/sourcecontrols@2023-12-01' = {
  name: '${webAppName}/web'
  dependsOn: [
    webApp
    mainSlotAppSettings
  ]
  properties: {
    repoUrl: externalGitRepoUrl
    branch: externalGitBranch
    isManualIntegration: true
  }
}

// Configure app settings for main slot (Application Insights)
resource mainSlotAppSettings 'Microsoft.Web/sites/config@2023-12-01' = {
  name: '${webAppName}/appsettings'
  dependsOn: [
    webApp
  ]
  properties: {
    PROJECT: appSourcePath
    APPLICATIONINSIGHTS_CONNECTION_STRING: enableApplicationInsights ? appInsights!.properties.ConnectionString : ''
    ApplicationInsightsAgent_EXTENSION_VERSION: '~3'
  }
}

// Variable to check if slots are supported (Standard tier and above)
var slotsSupported = !contains(['F1', 'B1', 'B2', 'B3'], skuName)

// Configure External Git deployment for broken slot (only when slots are supported)
resource slotSourceControl 'Microsoft.Web/sites/slots/sourcecontrols@2023-12-01' = if (slotsSupported) {
  name: '${webAppName}/broken/web'
  dependsOn: [
    webApp
  ]
  properties: {
    repoUrl: externalGitRepoUrl
    branch: externalGitBranch
    isManualIntegration: true
  }
}

// Configure app setting for broken slot to enable error injection (only when slots are supported)
resource brokenSlotAppSettings 'Microsoft.Web/sites/slots/config@2023-12-01' = if (slotsSupported) {
  name: '${webAppName}/broken/appsettings'
  dependsOn: [
    slotSourceControl
  ]
  properties: {
    PROJECT: appSourcePath
    INJECT_ERROR: '1'
    APPLICATIONINSIGHTS_CONNECTION_STRING: enableApplicationInsights ? appInsights!.properties.ConnectionString : ''
    ApplicationInsightsAgent_EXTENSION_VERSION: '~3'
  }
}

// Outputs
@description('The resource ID of the App Service Plan.')
output appServicePlanId string = appServicePlan.outputs.resourceId

@description('The name of the App Service Plan.')
output appServicePlanName string = appServicePlan.outputs.name

@description('The resource ID of the Web App.')
output webAppId string = webApp.outputs.resourceId

@description('The name of the Web App.')
output webAppName string = webApp.outputs.name

@description('The default hostname of the Web App.')
output webAppDefaultHostname string = webApp.outputs.defaultHostname

@description('The URL of the Web App.')
output webAppUrl string = 'https://${webApp.outputs.defaultHostname}'

@description('The resource ID of Application Insights.')
output appInsightsId string = enableApplicationInsights ? appInsights!.id : ''

@description('The instrumentation key of Application Insights.')
output appInsightsInstrumentationKey string = enableApplicationInsights
  ? appInsights!.properties.InstrumentationKey
  : ''
