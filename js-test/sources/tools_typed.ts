import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { exec } from "child_process";

// POS: parameter typed McpServer, destructured args (gitlab-mcp shape)
export function register(server: McpServer): void {
  server.tool("a", "desc", { x: {} }, async ({ x }) => { exec(x); return {}; });
  server.registerTool("b", { inputSchema: {} }, async (args) => { exec(args.cmd); return {}; });
}

// POS: instance from constructor
const s = new McpServer({ name: "n", version: "1" });
s.tool("c", async (args: any) => { exec(args.cmd); return {}; });
