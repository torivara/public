# Firewall Rule Collection Group Module

Module for working around the current limitation of AzureRM Rule Collection Groups Application Rule Collection not being able to use Mssql port type.
If you are doing something that is supported, use the regular Terraform code.

This module will create a single Rule Collection Group with a single application type rule collection containing the rules you specify.

## Usage

```terraform
module "mssql_rcg" {
  source                         = "modules/firewall_rule_collection_group_azapi"
  firewall_policy_id             = "policyid"
  firewall_policy_name           = "policyname"
  rule_collection_group_name     = "NameOfRuleCollection"
  rule_collection_group_priority = prioritynumber
  rules = [
    {
      ruleType = "ApplicationRule"
      name     = "rulename"
      protocols = [
        {
          protocolType = "Mssql"
          port         = 1433
        }
      ]
      terminateTls = false
      sourceAddresses = [
        "10.10.10.50/32",
        "10.10.11.0/24"
      ]
      targetFqdns = [
        "my-mssqldb.database.windows.net"
      ]
    }
  ]
}
```

## Rules variable example

```terraform
[
  {
    ruleType = "ApplicationRule"
    name = "allow-inbound-1433-to-sql-private-endpoints"
    protocols = [
      {
        protocolType = "Mssql"
        port = 1433
      }
    ]
    terminateTls = false
    sourceAddresses = [
      "10.0.0.0/24"
    ]
    targetFqdns = [
      "yoursql.database.windows.net"
    ]
  }
]
```

## Inputs

|Name|Required|Type|Default|
|---|---|---|---|
|firewall_policy_id|Yes|String|N/A|
|api_version|No|String|2021-08-01|
|firewall_rule_collection_group_name|No|String|MssqlWorkaroundRuleCollection|
|firewall_rule_collection_group_priority|No|Number|900|
|rules|Yes|List of objects|N/A|

See above for rules structure example.

## Outputs

None
