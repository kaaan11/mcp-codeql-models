# POS (API graph only): no mcp import in this file, server object from a local module
from srv_module import mcp

@mcp.tool()
def remote_tool(filename: str):
    return filename
