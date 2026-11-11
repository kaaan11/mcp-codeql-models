/**
 * MCP entry points as remote flow sources for Python (ön kayıt 2026-11-03, §2).
 *
 * Only sources are added. Sinks, sanitizers and flow steps stay CodeQL's own;
 * every stock query that uses ActiveThreatModelSource picks these up once this
 * file is imported.
 *
 * Basis: MCP Python SDK (`mcp.server.fastmcp.FastMCP`, `mcp.server.MCPServer`,
 * `mcp.server.lowlevel.Server`) and `fastmcp.FastMCP` public APIs; the October
 * pilot's `McpSsrf.ql` registration logic.
 */

import python
import semmle.python.ApiGraphs
import semmle.python.dataflow.new.DataFlow
import semmle.python.dataflow.new.RemoteFlowSources

/** An MCP server instance, by import (followed across modules by the API graph). */
private API::Node mcpServer() {
  result =
    [
      API::moduleImport("mcp").getMember("server").getMember("fastmcp").getMember("FastMCP"),
      API::moduleImport("fastmcp").getMember("FastMCP"),
      API::moduleImport("mcp").getMember("server").getMember(["MCPServer", "Server"]),
      API::moduleImport("mcp").getMember("server").getMember("lowlevel").getMember("Server")
    ].getReturn()
}

/** Holds if `file` imports `mcp`, `fastmcp` or one of their submodules (exact names, not prefixes). */
private predicate importsMcp(File file) {
  exists(ImportingStmt s |
    s.getLocation().getFile() = file and
    s.getAnImportedModuleName().regexpMatch("(mcp|fastmcp)(\\..*)?")
  )
}

/**
 * Holds if decorator `d` registers its function as MCP `kind` (`tool` or `call_tool`),
 * with or without a call: `@mcp.tool`, `@mcp.tool()`, `@mcp.tool(name=...)`.
 */
private predicate registrationDecorator(Expr d, string kind) {
  kind = ["tool", "call_tool"] and
  (
    // API graph: receiver resolved to an MCP server instance.
    d = mcpServer().getMember(kind).getAValueReachableFromSource().asExpr()
    or
    d = mcpServer().getMember(kind).getACall().asExpr()
    or
    // Fallback for receivers the API graph cannot resolve (e.g. `self.server`),
    // only in files that import the MCP modules.
    exists(Attribute a |
      a.getName() = kind and
      importsMcp(d.getLocation().getFile()) and
      (d = a or d.(Call).getFunc() = a)
    )
  )
}

/** Holds if `f` is registered as an MCP handler of `kind`. */
private predicate registered(Function f, string kind) {
  registrationDecorator(f.getADecorator(), kind)
  or
  // `mcp.add_tool(fn)` / `mcp.add_tool(wrapper(fn))`: the pilot's registration-wrapper case.
  kind = "tool" and
  exists(Call c, Expr arg |
    c.getFunc().(Attribute).getName() = "add_tool" and
    (c = mcpServer().getMember("add_tool").getACall().asExpr() or importsMcp(c.getLocation().getFile())) and
    arg = c.getArg(0) and
    (
      arg.(Name).getId() = f.getName()
      or
      arg.(Call).getAnArg().(Name).getId() = f.getName()
    ) and
    f.getScope() = c.getScope()
  )
}

/** Holds if `p` is annotated as the FastMCP `Context`, which the server injects. */
private predicate isContextParam(Parameter p) {
  p.getAnnotation().(Name).getId() = "Context" or
  p.getAnnotation().(Attribute).getName() = "Context"
}

/** A parameter of an MCP tool function: a client-supplied tool argument. */
class McpToolParameter extends RemoteFlowSource::Range {
  McpToolParameter() {
    exists(Function f, Parameter p |
      registered(f, "tool") and
      this = DataFlow::parameterNode(p) and
      (p = f.getAnArg() or p = f.getAKeywordOnlyArg() or p = f.getKwarg() or p = f.getVararg()) and
      not p.isSelf() and
      not p.getName() = "cls" and
      not isContextParam(p)
    )
  }

  override string getSourceType() { result = "MCP tool argument" }
}

/** The `arguments` of a low-level `@server.call_tool()` handler `(name, arguments)`. */
class McpCallToolArguments extends RemoteFlowSource::Range {
  McpCallToolArguments() {
    exists(Function f, Parameter p |
      registered(f, "call_tool") and
      this = DataFlow::parameterNode(p) and
      (p.getName() = "arguments" or p = f.getArg(1) and not f.isMethod())
    )
  }

  override string getSourceType() { result = "MCP CallTool arguments" }
}
