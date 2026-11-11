from mcp.server.lowlevel import Server

server = Server("low")

@server.call_tool()
async def handle(name: str, arguments: dict):  # POS arguments; NEG name
    return arguments

class Wrapper:
    def __init__(self):
        self.server = Server("w")

        @self.server.call_tool()
        async def inner(tool_name, args):  # POS args (fallback: self.server)
            return args
