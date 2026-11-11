/**
 * @name MCP tool parameter to HTTP URL
 * @description Tracks MCP tool inputs through global taint flow to HTTP URL parts.
 * @kind path-problem
 * @problem.severity warning
 * @precision medium
 * @id pilot/mcp-ssrf
 * @tags security
 *       external/cwe/cwe-918
 */

import python
import semmle.python.ApiGraphs
import semmle.python.Concepts
import semmle.python.dataflow.new.DataFlow
import semmle.python.dataflow.new.TaintTracking

// Track function values for explicit registration and registration-wrapper calls.
module FunctionReferenceConfig implements DataFlow::ConfigSig {
  predicate isSource(DataFlow::Node n) {
    n.asExpr() = any(Function f).getDefinition()
  }

  predicate isSink(DataFlow::Node n) {
    exists(Call c | n.asExpr() = c.getFunc() or n.asExpr() = c.getArg(0))
  }
}

module FunctionReferences = DataFlow::Global<FunctionReferenceConfig>;

// This is static activation, not proof that a runtime branch is taken.
predicate activeScope(Scope scope) {
  scope instanceof Module
  or
  exists(Class c | scope = c and activeScope(c.getScope()))
  or
  exists(Function f, Call c |
    scope = f and activeScope(c.getScope()) and
    FunctionReferences::flow(DataFlow::exprNode(f.getDefinition()), DataFlow::exprNode(c.getFunc()))
  )
}

// Receiver names/types are deliberately unconstrained: a server may be imported
// or passed into a registration wrapper. This is a structural overapproximation.
predicate registered(Function f, string kind) {
  activeScope(f.getEnclosingScope()) and
  exists(Call factory, Attribute attr |
    factory = f.getADecorator() and factory.getFunc() = attr and
    (
      attr.getName() = "tool" and kind = "tool-decorator"
      or
      attr.getName() = "call_tool" and kind = "call-tool-arguments"
    )
  )
  or
  exists(Call registration, Expr callback |
    activeScope(registration.getScope()) and callback = registration.getArg(0) and
    not callback instanceof CallableExpr and
    FunctionReferences::flow(DataFlow::exprNode(f.getDefinition()), DataFlow::exprNode(callback)) and
    (
      registration.getFunc().(Attribute).getName() = "add_tool" and kind = "add-tool"
      or
      registration.getFunc().(Call).getFunc().(Attribute).getName() = "tool" and
      kind = "tool-factory-registration"
    )
  )
}

string sourceKind(DataFlow::Node n) {
  exists(Function f, Parameter p, string kind |
    registered(f, kind) and n = DataFlow::parameterNode(p) and
    (p = f.getAnArg() or p = f.getAKeywordOnlyArg() or p = f.getKwarg()) and
    not p.isSelf() and
    (kind != "call-tool-arguments" or p.getName() = "arguments") and
    result = kind
  )
}

// A deliberately limited syntactic indicator; it does not establish safety.
predicate hasGuardHint(Scope scope) {
  exists(Call c, string name |
    c.getScope() = scope and
    (name = c.getFunc().(Attribute).getName() or name = c.getFunc().(Name).getId()) and
    (
      name in ["urlparse", "urlsplit", "ip_address", "is_global", "is_private", "startswith", "validate_url", "is_safe_url"]
      or name.matches("%validate%url%")
      or name.matches("%safe%url%")
    )
  )
}

// Nominal annotation hints deliberately do not require a particular receiver name.
predicate typedClientRequest(Call request, string method, string clientType) {
  exists(Parameter parameter, Expr annotation, DataFlow::MethodCallNode call |
    annotation = parameter.getAnnotation() and
    clientType in ["Client", "AsyncClient", "Session", "ClientSession", "PoolManager", "HTTPConnectionPool", "HTTPSConnectionPool", "OpenerDirector"] and
    (
      annotation.(Name).getId() = clientType
      or annotation.(Attribute).getName() = clientType
      or annotation.(StringLiteral).getText() in [clientType, "httpx." + clientType, "requests." + clientType, "aiohttp." + clientType, "urllib3." + clientType]
    ) and
    request = call.asExpr() and method = call.getMethodName() and
    (httpVerb(method) or method = "open" and clientType = "OpenerDirector") and
    DataFlow::localFlow(DataFlow::parameterNode(parameter), call.getObject())
  )
}

predicate httpVerb(string method) {
  method in ["get", "post", "put", "patch", "delete", "head", "options", "request", "stream", "urlopen"]
}

// Supplement unresolved object fields without treating every dictionary.get as HTTP.
predicate fallbackRequest(Call c, string method) {
  exists(Attribute attr |
    c.getFunc() = attr and method = attr.getName() and httpVerb(method) and
    (
      attr.getObject().(Attribute).getName() in ["session", "client", "http_client", "http", "pool"]
      or
      attr.getObject().(Name).getId() in ["session", "client", "http_client"]
    )
  )
}

predicate sinkInfo(DataFlow::Node n, Call request, string api) {
  exists(Http::Client::Request r |
    n = r.getAUrlPart() and request = r.asExpr() and api = r.getFramework()
  )
  or
  exists(string method |
    (
      exists(string clientType |
        typedClientRequest(request, method, clientType) and api = "typed-client." + clientType + "." + method
      )
      or
      fallbackRequest(request, method) and not typedClientRequest(request, _, _) and
      api = "object-fallback." + method
    ) and
    not exists(Http::Client::Request known | known.asExpr() = request and n = known.getAUrlPart()) and
    (
      exists(Keyword keyword |
        keyword = request.getAKeyword() and keyword.getArg() = "url" and n.asExpr() = keyword.getValue()
      )
      or
      if method in ["request", "stream"]
      then n.asExpr() = request.getArg(1)
      else n.asExpr() = request.getArg(0)
    )
  )
  or
  // The client receiver carries base_url taint to an actual outgoing request.
  exists(DataFlow::MethodCallNode call, API::CallNode constructor, string method |
    request = call.asExpr() and method = call.getMethodName() and httpVerb(method) and
    baseClientConstructor(constructor) and
    call = constructor.getReturn().getMember(method).getACall() and
    n = call.getObject() and api = "client-base-url." + method
  )
}

predicate baseClientConstructor(API::CallNode constructor) {
  constructor = API::moduleImport("httpx").getMember(["Client", "AsyncClient"]).getACall()
  or
  constructor = API::moduleImport("aiohttp").getMember("ClientSession").getACall()
}

predicate baseUrlStep(DataFlow::Node nodeFrom, DataFlow::Node nodeTo) {
  exists(API::CallNode constructor |
    baseClientConstructor(constructor) and
    nodeFrom = constructor.getArgByName("base_url") and nodeTo = constructor
  )
}

module McpConfig implements DataFlow::ConfigSig {
  predicate isSource(DataFlow::Node n) { exists(sourceKind(n)) }
  predicate isSink(DataFlow::Node n) { sinkInfo(n, _, _) }
  predicate isAdditionalFlowStep(DataFlow::Node nodeFrom, DataFlow::Node nodeTo) { baseUrlStep(nodeFrom, nodeTo) }
  // No SSRF barriers: guard hints are reported without suppressing paths.
}

module McpFlow = TaintTracking::Global<McpConfig>;
import McpFlow::PathGraph

// This is an existential hint on a source-sink graph route, not a dominating guard.
string routeGuardSeen(McpFlow::PathNode source, McpFlow::PathNode sink) {
  if exists(McpFlow::PathNode middle |
    middle = source.getASuccessor*() and
    sink = middle.getASuccessor*() and
    hasGuardHint(middle.getNode().getScope())
  )
  then result = "syntactic-route-hint"
  else result = "not-detected"
}

string nodeKey(DataFlow::Node node) {
  result = node.getLocation().getFile().getRelativePath() + ":" +
    node.getLocation().getStartLine().toString() + ":" +
    node.getLocation().getStartColumn().toString()
}

from McpFlow::PathNode source, McpFlow::PathNode sink, Call request, string api
where
  McpFlow::flowPath(source, sink) and sinkInfo(sink.getNode(), request, api)
select request, source, sink,
  "MCP input reaches HTTP URL; source_kind=" + sourceKind(source.getNode()) +
    "; http_api=" + api + "; guard_seen=" + routeGuardSeen(source, sink) +
    "; source_key=" + nodeKey(source.getNode()) + "; flow_sink_key=" + nodeKey(sink.getNode()) + "."
