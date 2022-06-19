terraform {
  required_providers {
    azapi = {
      source = "azure/azapi"
    }
  }
}

locals {
  policy_array         = split("/", var.firewall_policy_id)
  firewall_policy_name = local.policy_array[8]
  resource_group_name  = local.policy_array[4]
}

data "azurerm_firewall_policy" "fwpolicy" {
  name                = local.firewall_policy_name
  resource_group_name = local.resource_group_name
}

resource "azapi_resource" "rule_collection_group" {
  type      = "Microsoft.Network/firewallPolicies/ruleCollectionGroups@${var.api_version}"
  name      = var.firewall_rule_collection_group_name
  parent_id = var.firewall_policy_id

  body = jsonencode({
    name = var.firewall_rule_collection_group_name
    properties = {
      priority = var.firewall_rule_collection_group_priority
      ruleCollections = [
        {
          ruleCollectionType = "FirewallPolicyFilterRuleCollection"
          name               = "allowMssqlWorkarounds"
          priority           = 1000
          action = {
            type = "Allow"
          }
          rules = var.rules
        }
      ]
    }
  })
}
