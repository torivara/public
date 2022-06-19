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
  description = "Name of the new rule collection group"
}

variable "firewall_rule_collection_group_priority" {
  type        = number
  description = "Priority of your Rule Collection Group"
}

variable "rules" {
  type        = list(object({ ruleType = string, name = string, protocols = list(object({ protocolType = string, port = number })), terminateTLS = bool, sourceAddresses = list(string), targetFqdns = list(string) }))
  description = "Complete rules list for the rule collection"
}

# variable "rule_collections" {
#   type        = list(object({ ruleCollectionType = string, name = string, priority = number, action = object({ type = string }), rules = list(object({ ruleType = string, name = string, protocols = list(object({ protocolType = string, port = number })), terminateTLS = bool, sourceAddresses = list(string), targetFqdns = list(string) })) }))
#   description = "Complete rule collections list"
#   default = [{
#     action = {
#       type = "Allow"
#     }
#     name               = "allowMssqlInboundCollection"
#     priority           = 1000
#     ruleCollectionType = "FirewallPolicyFilterRuleCollection"
#     rules              = var.rules
#   }]
# }

# variable "source_addresses" {
#   type        = list(string)
#   description = "Source addresses for opening"
#   default     = []
# }

# variable "target_fqdns" {
#   type        = list(string)
#   description = "Target FQDNs for opening"
#   default     = []
# }
