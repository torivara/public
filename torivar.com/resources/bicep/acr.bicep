@description('Prefix for resources.')
param prefix string

@minLength(5)
@maxLength(40)
@description('Name of your Azure Container Registry. Will be prefixed.')
param acrName string

@description('Enable admin user that have push / pull permission to the registry.')
param acrAdminUserEnabled bool = false

@allowed([
  'Enabled'
  'Disabled'
])
@description('Enable or disable public network access.')
param publicNetworkAccess string = 'Enabled'

@allowed([
  'Allow'
  'Deny'
])
@description('Default network rule set action.')
param networkDefaultAction string = 'Allow'

@description('Location for all resources.')
param location string = resourceGroup().location

@allowed([
  'Basic'
  'Standard'
  'Premium'
])
@description('Tier of your Azure Container Registry.')
param acrSku string = 'Basic'

var acrName_var = '${prefix}acr${acrName}'
var networkRuleSet = {
  defaultAction: networkDefaultAction
}

resource acr 'Microsoft.ContainerRegistry/registries@2019-12-01-preview' = {
  name: acrName_var
  location: location
  tags: {
    displayName: 'Container Registry'
    'container.registry': acrName_var
  }
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: acrAdminUserEnabled
    publicNetworkAccess: publicNetworkAccess
    networkRuleSet: acrSku != 'Premium' ? json('null') : networkRuleSet
  }
}

output acrLoginServer string = reference(acr.id, '2019-12-01-preview').loginServer
