// NEG: .tool on something unrelated, no MCP import in this file
const toolbox = { tool(name: string, cb: (a: any) => any) { return cb({}); } };
toolbox.tool("x", (a) => a.y);
// NEG: setRequestHandler with a local schema object of the same name
const CallToolRequestSchema = {};
const fake = { setRequestHandler(s: any, h: any) {} };
fake.setRequestHandler(CallToolRequestSchema, (req: any) => req.params.arguments);
