import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { exec } from "child_process";
export function register(server: McpServer) {
  server.tool("run", { cmd: {} }, async ({ cmd }) => { exec("ls " + cmd); return {}; });
  // NEG: constant command
  server.tool("safe", async () => { exec("ls /tmp"); return {}; });
}
