# mcp-codeql-models

CodeQL source models that make **Model Context Protocol (MCP) tool arguments**
visible to CodeQL's stock security queries, for Python and JavaScript/TypeScript.

Stock CodeQL does not know that the parameters of an MCP tool handler are
attacker-influenced input, so its taint queries stay silent on MCP servers.
These packs add the sources and nothing else: sinks, sanitizers and flow steps
remain CodeQL's own.

This is a research instrument, not a product. It was extracted from a larger
scanner project that was closed on 2026-11-03; the numbers below are what was
measured before that, including the ones that are not flattering.

## Contents

| Path | What it is |
| --- | --- |
| `py/McpSources.qll` | Python sources: `@mcp.tool` parameters (MCP SDK FastMCP, `fastmcp`), `add_tool(fn)`, low-level `@server.call_tool()` arguments |
| `py/queries/` | Stock CodeQL queries re-exported with the MCP sources imported (code injection, command injection, SSRF, path injection) |
| `js/McpSources.qll` | JavaScript/TypeScript sources for the MCP TypeScript SDK |
| `js/queries/` | Same idea for JS/TS (code injection, command injection, request forgery, tainted path) |
| `py-test/`, `js-test/` | CodeQL unit tests: positive and negative source fixtures, end-to-end flow fixtures |
| `tools/mutate_py.py`, `tools/mutate_js.py` | Mutation check: each mutation removes one model branch and a test must go red |
| `ssrf-pilot/` | The earlier, standalone pilot query `McpSsrf.ql` (Python, tool argument to HTTP URL) and its model notes |
| `MODEL-FREEZE-*.txt` | SHA-256 of the model files as frozen before the held-out measurement |

## Running

Developed and tested with the CodeQL CLI bundle 2.27.2.

```bash
# unit tests
codeql test run py-test js-test

# analyse a database
codeql database create db --language=python --source-root /path/to/server
codeql database analyze db py/queries --format=sarif-latest --output=out.sarif
```

Mutation check (pass the checkout directory):

```bash
python tools/mutate_py.py "$PWD"
python tools/mutate_js.py "$PWD"
```

The scripts expect the CodeQL binary at `~/tools/codeql-2.27.2/codeql/codeql`;
edit the path at the top if yours differs.

## What was measured

All measurements used pre-registered decision rules written before the run.

**Held-out set (2026-11-03), 8 unseen MCP servers, 3 of them with a known, already
public vulnerability used as a control:**

| Measure | Result |
| --- | --- |
| Known vulnerabilities found | 2 of 3 with these models, 0 of 3 with stock CodeQL (n = 3) |
| Triage volume | 17 units across the 8 targets |
| New confirmed vulnerabilities | **0** |

So the models make known MCP flaws visible where stock CodeQL sees nothing, and
the alert volume is small enough to read by hand. They did not, in this set,
lead to a new finding.

**`ssrf-pilot/McpSsrf.ql` (2026-10):** 15 of 19 on a labelled SSRF corpus. That
corpus was also used while writing the query, so treat it as a development
score. On 10 repositories outside the corpus it produced 32 raw results, most of
them false positives.

## Known gaps

- **SDK re-exports (JS/TS).** A server that re-exports the SDK through its own
  module (`export {McpServer} from '@modelcontextprotocol/sdk/...'`) yields no
  sources. This is the control the held-out run missed.
- **Context parameters (Python).** Only parameters annotated `Context` are
  excluded. An application's own context type is treated as a tool argument.
- **Mutation coverage is narrow.** The check has 9 hand-written mutations per
  language. All 18 are killed as of 2026-11-11 (see `tools/mutation-result-*.txt`);
  a model branch without a mutation is not covered by that statement.
- **False positives come from CodeQL's side.** Hand-written guards
  (`startsWith(cwd)`, host allowlists) are not recognised as sanitizers, and
  tools whose documented job is to read local files are reported anyway.
- **`*subprocess_exec(*argv)`** style sinks are not modelled by CodeQL.

## License

MIT, see `LICENSE`. The query files under `py/queries/` and `js/queries/` are
thin variants of queries from [github/codeql](https://github.com/github/codeql)
(MIT). Using the CodeQL CLI itself is subject to GitHub's CodeQL terms.
