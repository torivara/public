# Some useful Kusto queries

## Azure Firewall

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
