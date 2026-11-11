import subprocess
import requests
from mcp.server.fastmcp import FastMCP
from mcp.server.lowlevel import Server

mcp = FastMCP("e2e")

@mcp.tool
def run(cmd: str):
    return subprocess.run(cmd, shell=True)  # CWE-78

@mcp.tool()
def read(path: str):
    with open(path) as f:  # CWE-22
        return f.read()

@mcp.tool()
def fetch(url: str):
    return requests.get(url).text  # CWE-918 full

@mcp.tool()
def fetch_path(page: str):
    return requests.get("https://api.example.com/" + page).text  # CWE-918 partial

@mcp.tool()
def calc(expr: str):
    return eval(expr)  # CWE-94

@mcp.tool()
def safe():
    return subprocess.run("ls /tmp", shell=True)  # NEG: constant

server = Server("low")

@server.call_tool()
async def handle(name: str, arguments: dict):
    return subprocess.run(arguments["cmd"], shell=True)  # CWE-78 via call_tool
