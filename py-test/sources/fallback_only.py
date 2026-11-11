# POS (fallback only): server arrives as an untyped parameter of a never-called
# registration function; the file imports the mcp package, so the fallback applies.
from mcp.server.fastmcp import Context

def register(srv):
    @srv.tool()
    def plugin_tool(item: str, ctx: Context):  # POS item; NEG ctx
        return item
