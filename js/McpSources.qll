/**
 * MCP entry points as remote flow sources (ön kayıt 2026-11-03, §2).
 *
 * Only sources are added. Sinks, sanitizers and flow steps stay CodeQL's own;
 * every stock query that uses ActiveThreatModelSource picks these up once this
 * file is imported.
 */

import javascript

private string mcpServerModule() {
  result =
    [
      "@modelcontextprotocol/sdk/server/mcp.js", "@modelcontextprotocol/sdk/server/mcp",
      "@modelcontextprotocol/sdk/server/index.js", "@modelcontextprotocol/sdk/server/index"
    ]
}

private string mcpTypesModule() {
  result = ["@modelcontextprotocol/sdk/types.js", "@modelcontextprotocol/sdk/types"]
}

/** A reference to an MCP `McpServer` or low-level `Server`, by import or by declared type. */
private API::Node mcpServer() {
  exists(string m, string cls | m = mcpServerModule() and cls = ["McpServer", "Server"] |
    result = API::moduleImport(m).getMember(cls).getInstance()
    or
    result = API::Node::ofType(m, cls)
  )
}

/**
 * The callback of `server.tool(name, ..., cb)` / `server.registerTool(name, config, cb)`.
 *
 * Fallback for receivers the API graph cannot resolve (untyped parameters): a
 * `.tool`/`.registerTool` call with a string-literal name and a function last
 * argument, in a file that imports the MCP server module.
 */
private DataFlow::FunctionNode toolCallback() {
  exists(DataFlow::CallNode call |
    call = mcpServer().getMember(["tool", "registerTool"]).getACall()
    or
    call.(DataFlow::MethodCallNode).getMethodName() = ["tool", "registerTool"] and
    call.getArgument(0).asExpr() instanceof StringLiteral and
    exists(Import i |
      i.getFile() = call.getFile() and i.getImportedPathString() = mcpServerModule()
    )
  |
    result = call.getLastArgument().getAFunctionValue() and
    call.getNumArgument() >= 2
  )
}

/** First parameter of a tool callback: the tool arguments object. */
class McpToolArgument extends RemoteFlowSource {
  McpToolArgument() { this = toolCallback().getParameter(0) }

  override string getSourceType() { result = "MCP tool argument" }

  override predicate isUserControlledObject() { any() }
}

/**
 * `req.params.arguments` in `setRequestHandler(CallToolRequestSchema, (req) => ...)`.
 * Anchored on the schema import, not the receiver: `this.server` and
 * `mcpServer.server` are common and rarely typed.
 */
class McpCallToolArguments extends RemoteFlowSource {
  McpCallToolArguments() {
    exists(DataFlow::MethodCallNode call |
      call.getMethodName() = "setRequestHandler" and
      call.getArgument(0) =
        API::moduleImport(mcpTypesModule())
            .getMember("CallToolRequestSchema")
            .getAValueReachableFromSource() and
      this =
        call.getArgument(1)
            .getAFunctionValue()
            .getParameter(0)
            .getAPropertyRead("params")
            .getAPropertyRead("arguments")
    )
  }

  override string getSourceType() { result = "MCP CallTool arguments" }

  override predicate isUserControlledObject() { any() }
}

/**
 * Vercel function under a top-level `api/` folder with an untyped request:
 * `export default function handler(req, res)`. CodeQL's VercelNode model needs
 * the `VercelRequest` type and its Next model needs `pages/api` or `app/api`.
 */
class UntypedVercelRequestInput extends RemoteFlowSource {
  UntypedVercelRequestInput() {
    exists(Module m, DataFlow::FunctionNode f |
      m.getFile().getRelativePath().regexpMatch("(.*/)?api/.*") and
      f = m.getAnExportedValue("default").getAFunctionValue() and
      f.getNumParameter() = 2 and
      this = f.getParameter(0).getAPropertyRead(["body", "query"])
    )
  }

  override string getSourceType() { result = "Vercel request input" }

  override predicate isUserControlledObject() { any() }
}

/** Hono context request input: `c.req.json()`, `c.req.query()`, `c.req.param()`. */
class HonoRequestInput extends RemoteFlowSource {
  HonoRequestInput() {
    exists(DataFlow::FunctionNode handler, DataFlow::MethodCallNode call |
      handler =
        API::moduleImport("hono")
            .getMember("Hono")
            .getInstance()
            .getMember(["get", "post", "put", "patch", "delete", "all", "on", "use"])
            .getACall()
            .getAnArgument()
            .getAFunctionValue() and
      call = handler.getParameter(0).getAPropertyRead("req").getAMethodCall() and
      call.getMethodName() = ["json", "query", "param"]
    |
      // json() returns a promise; CodeQL's promise flow carries it through await.
      this = call
    )
  }

  override string getSourceType() { result = "Hono request input" }

  override predicate isUserControlledObject() { any() }
}
