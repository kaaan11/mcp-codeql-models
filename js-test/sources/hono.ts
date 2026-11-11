import { Hono } from "hono";
const app = new Hono();
// POS: json / query / param
app.post("/x", async (c) => { const b = await c.req.json(); const q = c.req.query("q"); const p = c.req.param("id"); return c.text(b + q + p); });
// NEG: header is not in the pre-registered list
app.get("/h", (c) => c.text(c.req.header("h") || ""));
