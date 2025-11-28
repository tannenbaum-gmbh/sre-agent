// Load Testing Module
// Deploys Azure Load Testing resource for simulating user load on the SRE Agent demo application
// Due to Azure Policy restrictions on storage account shared key access, the test configuration
// is handled via a post-deployment script (setup-load-test.sh) or GitHub Actions

@description('Required. Name prefix for resources.')
param namePrefix string

@description('Required. Location for the Load Testing resource.')
param location string

@description('Optional. Tags for all resources.')
param tags object = {}

@description('Optional. Enable the Load Testing resource.')
param enableLoadTesting bool = true

@description('Optional. Description for the Load Testing resource.')
param loadTestDescription string = 'Load testing for SRE Agent demo - simulates user traffic on the web application'

@description('Optional. Target web application URL for load testing (hostname only, no https://).')
param targetWebAppUrl string = 'app-sreagent.azurewebsites.net'

// Variables
var loadTestName = 'lt-${namePrefix}'

// Azure Load Testing Resource using AVM module
module loadTest 'br/public:avm/res/load-test-service/load-test:0.4.1' = if (enableLoadTesting) {
  name: '${uniqueString(deployment().name, location)}-loadtest'
  params: {
    name: loadTestName
    location: location
    tags: union(tags, {
      'sre-agent-component': 'load-testing'
    })
    loadTestDescription: loadTestDescription
    managedIdentities: {
      systemAssigned: true
    }
  }
}

// Outputs
@description('The resource ID of the Load Testing resource.')
output loadTestId string = enableLoadTesting ? loadTest!.outputs.resourceId : ''

@description('The name of the Load Testing resource.')
output loadTestName string = enableLoadTesting ? loadTest!.outputs.name : ''

@description('The principal ID of the Load Testing managed identity.')
output loadTestPrincipalId string = enableLoadTesting ? (loadTest!.outputs.?systemAssignedMIPrincipalId ?? '') : ''

@description('The data plane URI for the Load Testing resource.')
output loadTestDataPlaneUri string = enableLoadTesting
  ? 'https://${loadTestName}.${location}.cnt-prod.loadtesting.azure.com'
  : ''

@description('The target web app URL for load testing.')
output targetUrl string = targetWebAppUrl

@description('Instructions for setting up and running the load test.')
output loadTestInstructions string = '''
=== Azure Load Testing - Setup Required ===

The Load Testing resource has been deployed successfully!

To complete setup, run the setup script:
  ./infra/scripts/setup-load-test.sh <resource-group> <load-test-name> <target-url>

Example:
  ./infra/scripts/setup-load-test.sh rg-sreagent lt-sreagent app-sreagent.azurewebsites.net

This will:
1. Create the load test with ID: sre-agent-load-test
2. Upload the JMeter test plan from infra/tests/sre-agent-load-test.jmx
3. Configure 50 virtual users with 30-minute duration

To run the load test after setup:
  az load test-run create \
    --load-test-resource lt-<prefix> \
    --resource-group <resource-group> \
    --test-id sre-agent-load-test \
    --test-run-id run-\$(date +%Y%m%d-%H%M%S)
'''
