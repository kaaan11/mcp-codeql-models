import javascript
import McpSources

from RemoteFlowSource s
where
  s instanceof McpToolArgument or
  s instanceof McpCallToolArguments or
  s instanceof UntypedVercelRequestInput or
  s instanceof HonoRequestInput
select s, s.getSourceType()
