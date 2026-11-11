import python
import McpSources

from RemoteFlowSource s
where s instanceof McpToolParameter or s instanceof McpCallToolArguments
select s, s.getSourceType()
