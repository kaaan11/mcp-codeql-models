import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
// POS (API graph only): non-literal tool name, fallback requires a string literal
const TOOL_NAME = "e";
const s = new McpServer({ name: "n", version: "1" });
s.tool(TOOL_NAME, async (args: any) => args.q);
