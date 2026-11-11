// KNOWN GAP (not modelled): API graph does not follow a local re-export; 0 occurrences in the corpus (2026-11-03).
import { McpServer } from "./reexport";
const r = new McpServer({ name: "n", version: "1" });
r.tool("f", async (args: any) => args.q);
