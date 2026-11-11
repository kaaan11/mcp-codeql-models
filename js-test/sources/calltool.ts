import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";

class S {
  server = new Server({ name: "n", version: "1" }, {});
  setup() {
    // POS: this.server receiver, request: any (tavily shape)
    this.server.setRequestHandler(CallToolRequestSchema, async (request: any) => {
      const a = request.params.arguments;
      return a;
    });
    // NEG: other schema
    this.server.setRequestHandler(ListToolsRequestSchema, async (request: any) => {
      return request.params.arguments;
    });
  }
}
