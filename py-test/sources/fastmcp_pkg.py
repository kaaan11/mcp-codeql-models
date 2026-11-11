from fastmcp import FastMCP
app = FastMCP("x")

@app.tool
def pkg_tool(target: str):  # POS target
    return target

@app.resource("file://{name}")
def res(name: str):  # NEG: resources are out of pre-registered scope
    return name
