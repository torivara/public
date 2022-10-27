# Some useful Kusto queries

- [IPv4 addresses index operator](https://learn.microsoft.com/en-us/azure/data-explorer/kusto/query/datatypes-string-operators#operators-on-ipv4-addresses)
- [Query best practices](https://learn.microsoft.com/en-us/azure/data-explorer/kusto/query/best-practices)

## Azure Firewall

### All traffic

[Source](https://gist.github.com/marknettle/13fd0c49fe9eeb400572b279790f78bf)

```kusto
AzureDiagnostics
| where ResourceType == "AZUREFIREWALLS"
| extend
     proto =      extract(@"^([A-Z]+) ",1,msg_s)
    ,src_host =   extract(@"request from ([\d\.]*)",1,msg_s)
    ,src_port =   extract(@"request from [\d\.]*:(\d+)",1,msg_s)
    ,dest_host =  extract(@" to ([-\w\.]+)(:|\. |\.$)",1,msg_s)
    ,dest_port =  extract(@" to [-\w\.]+:(\d+)",1,msg_s)
    ,action =     iif(
       msg_s has "was denied"
      ,"Deny"
      ,extract(@" Action: (\w+)",1,msg_s))
    ,rule_coll =  extract(@" Rule Collection: (\w+)",1,msg_s)
    ,rule =       coalesce(
       extract(@" Rule: (.*)",1,msg_s)
      ,extract("No rule matched",0,msg_s))
    ,reason =     extract(@" Reason: (.*)",1,msg_s)
| project TimeGenerated,Category,proto,src_host,src_port,dest_host,dest_port,action,rule_coll,rule,reason,msg_s
```

### Denied traffic from specified host

This excludes dns proxy traffic to reduce result noise.

```kusto
AzureDiagnostics
| where ResourceType == "AZUREFIREWALLS" and Category != "AzureFirewallDnsProxy"
| extend
     proto =      extract(@"^([A-Z]+) ",1,msg_s)
    ,src_host =   extract(@"request from ([\d\.]*)",1,msg_s)
    ,src_port =   extract(@"request from [\d\.]*:(\d+)",1,msg_s)
    ,dest_host =  extract(@" to ([-\w\.]+)(:|\. |\.$)",1,msg_s)
    ,dest_port =  extract(@" to [-\w\.]+:(\d+)",1,msg_s)
    ,action =     iif(
       msg_s has "was denied"
      ,"Deny"
      ,extract(@" Action: (\w+)",1,msg_s))
    ,rule_coll =  extract(@" Rule Collection: (\w+)",1,msg_s)
    ,rule =       coalesce(
       extract(@" Rule: (.*)",1,msg_s)
      ,extract("No rule matched",0,msg_s))
    ,reason =     extract(@" Reason: (.*)",1,msg_s)
| where src_host == "10.0.0.1"
| project TimeGenerated,Category,proto,src_host,src_port,dest_host,dest_port,action,rule_coll,rule,reason,msg_s
```

### Denied traffic to specified fqdn from specified host

This excludes dns proxy traffic to reduce result noise.

```kusto
AzureDiagnostics
| where ResourceType == "AZUREFIREWALLS" and Category != "AzureFirewallDnsProxy"
| extend
     proto =      extract(@"^([A-Z]+) ",1,msg_s)
    ,src_host =   extract(@"request from ([\d\.]*)",1,msg_s)
    ,src_port =   extract(@"request from [\d\.]*:(\d+)",1,msg_s)
    ,dest_host =  extract(@" to ([-\w\.]+)(:|\. |\.$)",1,msg_s)
    ,dest_port =  extract(@" to [-\w\.]+:(\d+)",1,msg_s)
    ,action =     iif(
       msg_s has "was denied"
      ,"Deny"
      ,extract(@" Action: (\w+)",1,msg_s))
    ,rule_coll =  extract(@" Rule Collection: (\w+)",1,msg_s)
    ,rule =       coalesce(
       extract(@" Rule: (.*)",1,msg_s)
      ,extract("No rule matched",0,msg_s))
    ,reason =     extract(@" Reason: (.*)",1,msg_s)
| where src_host == "10.0.0.1" and dest_host == "www.google.com"
| project TimeGenerated,Category,proto,src_host,src_port,dest_host,dest_port,action,rule_coll,rule,reason,msg_s
```

## Advanced firewall search

Filters the result before parsing, which saves execution time.

```kusto
AzureDiagnostics
| where TimeGenerated > ago(30d)
| where Category == "AzureFirewallNetworkRule" or Category == "AzureFirewallApplicationRule"
| where has_any_ipv4_prefix(msg_s, dynamic(["10.0.0.","10.0.1.","10.1.0."]))
//optionally apply filters to only look at a certain type of log data
//| where OperationName == "AzureFirewallNetworkRuleLog"
//| where OperationName == "AzureFirewallNatRuleLog"
//| where OperationName == "AzureFirewallApplicationRuleLog"
//| where OperationName == "AzureFirewallIDSLog"
//| where OperationName == "AzureFirewallThreatIntelLog"
| extend msg_original = msg_s
// normalize data so it's eassier to parse later
| extend msg_s = replace(@'. Action: Deny. Reason: SNI TLS extension was missing.', @' to no_data:no_data. Action: Deny. Rule Collection: default behavior. Rule: SNI TLS extension missing', msg_s)
| extend msg_s = replace(@'No rule matched. Proceeding with default action', @'Rule Collection: default behavior. Rule: no rule matched', msg_s)
// extract web category, then remove it from further parsing
| parse msg_s with * " Web Category: " WebCategory
| extend msg_s = replace(@'(. Web Category:).*','', msg_s)
// extract RuleCollection and Rule information, then remove it from further parsing
| parse msg_s with * ". Rule Collection: " RuleCollection ". Rule: " Rule
| extend msg_s = replace(@'(. Rule Collection:).*','', msg_s)
// extract Rule Collection Group information, then remove it from further parsing
| parse msg_s with * ". Rule Collection Group: " RuleCollectionGroup
| extend msg_s = replace(@'(. Rule Collection Group:).*','', msg_s)
// extract Policy information, then remove it from further parsing
| parse msg_s with * ". Policy: " Policy
| extend msg_s = replace(@'(. Policy:).*','', msg_s)
// extract IDS fields, for now it's always add the end, then remove it from further parsing
| parse msg_s with * ". Signature: " IDSSignatureIDInt ". IDS: " IDSSignatureDescription ". Priority: " IDSPriorityInt ". Classification: " IDSClassification
| extend msg_s = replace(@'(. Signature:).*','', msg_s)
// extra NAT info, then remove it from further parsing
| parse msg_s with * " was DNAT'ed to " NatDestination
| extend msg_s = replace(@"( was DNAT'ed to ).*",". Action: DNAT", msg_s)
// extract Threat Intellingence info, then remove it from further parsing
| parse msg_s with * ". ThreatIntel: " ThreatIntel
| extend msg_s = replace(@'(. ThreatIntel:).*','', msg_s)
// extract URL, then remove it from further parsing
| extend URL = extract(@"(Url: )(.*)(\. Action)",2,msg_s)
| extend msg_s=replace(@"(Url: .*)(Action)",@"\2",msg_s)
// parse remaining "simple" fields
| parse msg_s with Protocol " request from " SourceIP " to " Target ". Action: " Action
| extend 
    SourceIP = iif(SourceIP contains ":",strcat_array(split(SourceIP,":",0),""),SourceIP),
    SourcePort = iif(SourceIP contains ":",strcat_array(split(SourceIP,":",1),""),""),
    Target = iif(Target contains ":",strcat_array(split(Target,":",0),""),Target),
    TargetPort = iif(SourceIP contains ":",strcat_array(split(Target,":",1),""),""),
    Action = iif(Action contains ".",strcat_array(split(Action,".",0),""),Action),
    Policy = case(RuleCollection contains ":", split(RuleCollection, ":")[0] ,Policy),
    RuleCollectionGroup = case(RuleCollection contains ":", split(RuleCollection, ":")[1], RuleCollectionGroup),
    RuleCollection = case(RuleCollection contains ":", split(RuleCollection, ":")[2], RuleCollection),
    IDSSignatureID = tostring(IDSSignatureIDInt),
    IDSPriority = tostring(IDSPriorityInt)
| project msg_original,TimeGenerated,Protocol,SourceIP,SourcePort,Target,TargetPort,URL,Action, NatDestination, OperationName,ThreatIntel,IDSSignatureID,IDSSignatureDescription,IDSPriority,IDSClassification,Policy,RuleCollectionGroup,RuleCollection,Rule,WebCategory
```

## Log Analytics Cost and Usage

[Source](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/analyze-usage)

### Billable data volume by computer for the last full day

```kusto
find where TimeGenerated between(startofday(ago(1d))..startofday(now())) project _BilledSize, _IsBillable, Computer, Type
| where _IsBillable == true and Type != "Usage"
| extend computerName = tolower(tostring(split(Computer, '.')[0]))
| summarize BillableDataBytes = sum(_BilledSize) by  computerName 
| sort by BillableDataBytes desc nulls last
```

### Billable data volume by solution over the past month

```kusto
Usage 
| where TimeGenerated > ago(32d)
| where StartTime >= startofday(ago(31d)) and EndTime < startofday(now())
| where IsBillable == true
| summarize BillableDataGB = sum(Quantity) / 1000. by bin(StartTime, 1d), Solution 
| render columnchart
```

### Billable data volume by solution and type over the past month

```kusto
Usage 
| where TimeGenerated > ago(32d)
| where StartTime >= startofday(ago(31d)) and EndTime < startofday(now())
| where IsBillable == true
| summarize BillableDataGB = sum(Quantity) / 1000 by Solution, DataType
| sort by Solution asc, DataType asc
```

## Application Gateway with Web Application Firewall

[Source](https://learn.microsoft.com/en-us/azure/application-gateway/log-analytics)

### Matched rules for hostname by rule group and id (for WAF exclusion) last day

```kusto
AzureDiagnostics
| where TimeGenerated > ago(1d)
| where ResourceType == "APPLICATIONGATEWAYS" and OperationName == "ApplicationGatewayFirewall"
| where action_s == "Matched" and hostname_s == "contoso.com"
| project hostname_s, ruleGroup_s, ruleId_s
| distinct ruleGroup_s, ruleId_s
```

### All traffic for hostname last day

```kusto
AzureDiagnostics
| where TimeGenerated > ago(1d)
| where ResourceType == "APPLICATIONGATEWAYS" and hostname_s == "contoso.com"
```

### All blocked traffic for hostname last day

```kusto
AzureDiagnostics
| where TimeGenerated > ago(1d)
| where ResourceType == "APPLICATIONGATEWAYS" and hostname_s == "contoso.com"
| where action_s == "Matched"
```

### Matched/Blocked requests by IP

```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog"
| summarize count() by clientIp_s, bin(TimeGenerated, 1m)
| render timechart
```

### Matched/Blocked requests by URI

```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog"
| summarize count() by requestUri_s, bin(TimeGenerated, 1m)
| render timechart
```

### Top matched rules

```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog"
| summarize count() by ruleId_s, bin(TimeGenerated, 1m)
| where count_ > 10
| render timechart
```

### Top five matched rule groups

```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog"
| summarize Count=count() by details_file_s, action_s
| top 5 by Count desc
| render piechart
```

### Failed requests pr hour

```kusto
AzureDiagnostics
| where ResourceType == "APPLICATIONGATEWAYS" and OperationName == "ApplicationGatewayAccess" and httpStatus_d > 399
| summarize AggregatedValue = count() by bin(TimeGenerated, 1h), _ResourceId
| render timechart
```
