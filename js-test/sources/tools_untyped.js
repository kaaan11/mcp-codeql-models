import "@modelcontextprotocol/sdk/server/mcp.js";
// POS (fallback): untyped receiver in a file importing the MCP server module
export function register(srv) {
  srv.tool("d", async (args) => args.q);
}
