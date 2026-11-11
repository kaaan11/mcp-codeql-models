from mcp.server.fastmcp import FastMCP, Context

mcp = FastMCP("demo")

@mcp.tool
def bare(path: str):  # POS path
    return path

@mcp.tool()
def called(cmd: str, *, flag: bool = False, **extra):  # POS cmd, flag, extra
    return cmd

@mcp.tool(name="named")
async def named(url: str, ctx: Context):  # POS url; NEG ctx (injected)
    return url

def plain_helper(x):  # NEG: not registered
    return x

def wrap(fn):
    return fn

def searched(q: str):  # POS q (add_tool via wrapper)
    return q

mcp.add_tool(wrap(searched))
