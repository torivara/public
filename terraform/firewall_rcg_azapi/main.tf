terraform {
  required_providers {
    azapi = {
      source      = "azure/azapi"
      versversion = "= 0.3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  policy_array         = split("/", var.firewall_policy_id)
  firewall_policy_name = local.policy_array[8]
  resource_group_name  = local.policy_array[4]
}

variable "firewall_policy_id" {
  type        = string
  description = "Firewall policy id"
}

variable "api_version" {
  type        = string
  description = "API Version of rule collection group"
  default     = "2021-08-01"
}

variable "firewall_rule_collection_group_name" {
  type        = string
  description = "Name of your firewall rule collection group. Defaults to 'default'."
  default     = "default"
}

data "azurerm_firewall_policy" "fwpolicy" {
  name                = local.firewall_policy_name
  resource_group_name = local.resource_group_name
}

resource "azapi_resource" "rule_collection_group" {
  type      = "Microsoft.Network/firewallPolicies/ruleCollectionGroups@${var.api_version}"
  name      = "Rule-Collection-Name"
  parent_id = var.firewall_policy_id

  body = jsonencode({
    name = var.firewall_rule_collection_group_name
    properties = {
      priority = 1000
      ruleCollections = [
        {
          ruleCollectionType = "FirewallPolicyFilterRuleCollection"
          name               = "ruleCollectionProd"
          priority           = 1000
          action = {
            type = "Allow"
          }
          rules = [
            {
              ruleType = "ApplicationRule"
              name     = "allow-inbound-to-prod-databases-from-somewhere"
              protocols = [
                {
                  protocolType = "Mssql"
                  port         = 1433
                }
              ]
              terminateTLS = false
              sourceAddresses = [
                "10.1.0.4/32",
                "10.1.0.5/32"
              ]
              targetFqdns = [
                "proddb01.database.windows.net",
                "proddb02.database.windows.net"
              ]
            }
          ]
        },
        {
          ruleCollectionType = "FirewallPolicyFilterRuleCollection"
          name               = "ruleCollectionTest"
          priority           = 1100
          action = {
            type = "Allow"
          }
          rules = [
            {
              ruleType = "ApplicationRule"
              name     = "allow-inbound-to-test-databases-from-somewhere"
              protocols = [
                {
                  protocolType = "Mssql"
                  port         = 1433
                }
              ]
              terminateTLS = false
              sourceAddresses = [
                "10.0.0.4/32",
                "10.0.0.5/32"
              ]
              targetFqdns = [
                "testdb01.database.windows.net",
                "testdb02.database.windows.net"
              ]
            }
          ]
        }
      ]
    }
  })
}
