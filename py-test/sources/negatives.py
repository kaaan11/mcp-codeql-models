# NEG: no mcp import; similarly named decorators from other frameworks
from mcp_workspace.utils import thing  # prefix only, not the mcp package

class Agent:
    def tool(self, fn):
        return fn

agent = Agent()

@agent.tool
def pydantic_style(ctx, query: str):
    return query

def tool(fn):
    return fn

@tool
def langchain_style(q: str):
    return q
