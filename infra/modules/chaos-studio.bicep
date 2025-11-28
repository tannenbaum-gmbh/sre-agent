// Chaos Studio Module
// Deploys Chaos Studio experiment with App Service targets and capabilities

@description('Required. Name prefix for resources.')
param namePrefix string

@description('Required. Location for the Chaos experiment.')
param location string

@description('Optional. Tags for all resources.')
param tags object = {}

@description('Required. The resource ID of the App Service to target.')
param appServiceResourceId string

@description('Optional. Enable the Chaos Studio target and experiment.')
param enableChaosStudio bool = true

@description('Optional. Duration of the chaos experiment (ISO 8601 format).')
param experimentDuration string = 'PT10M'

// Variables
var experimentName = 'chaos-exp-${namePrefix}'
var webAppName = last(split(appServiceResourceId, '/'))

// Reference the existing Web App
resource webApp 'Microsoft.Web/sites@2023-12-01' existing = {
  name: webAppName
}

// Chaos Studio Target - Enable App Service as a target
resource chaosTarget 'Microsoft.Chaos/targets@2024-01-01' = if (enableChaosStudio) {
  name: 'Microsoft-AppService'
  location: location
  scope: webApp
  properties: {}
}

// Chaos Studio Capability - Stop App Service
resource stopCapability 'Microsoft.Chaos/targets/capabilities@2024-01-01' = if (enableChaosStudio) {
  name: 'Stop-1.0'
  parent: chaosTarget
}

// Chaos Studio Capability - Kill Process (if available for App Service)
// Note: Not all capabilities are available for all resource types
// For App Service, the main capability is Stop

// Role Definition for Chaos Experiment (Website Contributor)
resource websiteContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'de139f84-1756-47ae-9be6-808fbbe84772' // Website Contributor role
}

// Chaos Studio Experiment
resource chaosExperiment 'Microsoft.Chaos/experiments@2024-01-01' = if (enableChaosStudio) {
  name: experimentName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    selectors: [
      {
        id: 'Selector1'
        type: 'List'
        targets: [
          {
            id: chaosTarget.id
            type: 'ChaosTarget'
          }
        ]
      }
    ]
    steps: [
      {
        name: 'Step1-StopAppService'
        branches: [
          {
            name: 'Branch1'
            actions: [
              {
                name: 'urn:csci:microsoft:appService:stop/1.0'
                type: 'continuous'
                duration: experimentDuration
                parameters: []
                selectorId: 'Selector1'
              }
            ]
          }
        ]
      }
    ]
  }
}

// Role Assignment - Grant Chaos Experiment permission to stop App Service
resource chaosRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableChaosStudio) {
  name: guid(webApp.id, chaosExperiment!.id, websiteContributorRole.id)
  scope: webApp
  properties: {
    roleDefinitionId: websiteContributorRole.id
    principalId: chaosExperiment!.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
@description('The resource ID of the Chaos Studio experiment.')
output experimentId string = enableChaosStudio ? chaosExperiment!.id : ''

@description('The name of the Chaos Studio experiment.')
output experimentName string = enableChaosStudio ? chaosExperiment!.name : ''

@description('The principal ID of the Chaos experiment managed identity.')
output experimentPrincipalId string = enableChaosStudio ? chaosExperiment!.identity.principalId : ''

@description('The resource ID of the Chaos target.')
output targetId string = enableChaosStudio ? chaosTarget!.id : ''
