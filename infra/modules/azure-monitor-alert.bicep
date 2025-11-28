// Azure Monitor Alert Module
// Deploys metric alerts for App Service monitoring to trigger SRE Agent

@description('Required. Name prefix for resources.')
param namePrefix string

@description('Optional. Location for all resources.')
param location string = 'global'

@description('Optional. Tags for all resources.')
param tags object = {}

@description('Required. Resource ID of the App Service to monitor.')
param appServiceResourceId string

@description('Optional. Enable Azure Monitor alerts.')
param enableMonitorAlerts bool = true

@description('Optional. Threshold for 5xx error count to trigger alert.')
@minValue(1)
param http5xxErrorThreshold int = 10

@description('Optional. Evaluation frequency for the alert (ISO 8601 duration).')
@allowed([
  'PT1M'
  'PT5M'
  'PT15M'
  'PT30M'
  'PT1H'
])
param evaluationFrequency string = 'PT5M'

@description('Optional. Window size for the alert evaluation (ISO 8601 duration).')
@allowed([
  'PT1M'
  'PT5M'
  'PT15M'
  'PT30M'
  'PT1H'
  'PT6H'
  'PT12H'
  'P1D'
])
param windowSize string = 'PT5M'

@description('Optional. Severity of the alert (0=Critical, 1=Error, 2=Warning, 3=Informational, 4=Verbose).')
@allowed([0, 1, 2, 3, 4])
param alertSeverity int = 0

// Variables
var alertName = 'alert-${namePrefix}-http5xx'
var alertDescription = 'Alert triggered when HTTP 5xx server errors exceed threshold. This alert is designed to wake up SRE Agent for automatic incident investigation.'

// Metric Alert for HTTP 5xx errors using AVM module
module http5xxAlert 'br/public:avm/res/insights/metric-alert:0.3.1' = if (enableMonitorAlerts) {
  name: '${uniqueString(deployment().name, location)}-http5xx-alert'
  params: {
    name: alertName
    location: location
    tags: union(tags, {
      'sre-agent-alert': 'true'
      'alert-type': 'http-5xx-errors'
    })
    alertDescription: alertDescription
    severity: alertSeverity
    enabled: true
    scopes: [
      appServiceResourceId
    ]
    evaluationFrequency: evaluationFrequency
    windowSize: windowSize
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allof: [
        {
          name: 'Http5xxErrorCount'
          criterionType: 'StaticThresholdCriterion'
          metricName: 'Http5xx'
          metricNamespace: 'Microsoft.Web/sites'
          operator: 'GreaterThanOrEqual'
          threshold: http5xxErrorThreshold
          timeAggregation: 'Total'
          dimensions: []
        }
      ]
    }
  }
}

// Outputs
@description('The resource ID of the HTTP 5xx alert.')
output http5xxAlertId string = enableMonitorAlerts ? http5xxAlert!.outputs.resourceId : ''

@description('The name of the HTTP 5xx alert.')
output http5xxAlertName string = enableMonitorAlerts ? http5xxAlert!.outputs.name : ''
