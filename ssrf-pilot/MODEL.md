# Round-2 pilot model

This pack uses `codeql/python-all` 7.2.7 from the offline CodeQL 2.27.2 bundle.
No target-specific module, file, function, or server instance name is encoded.

## Sources

`tool-decorator`: parameters of functions decorated with `receiver.tool(...)`.
`add-tool`: parameters of a function value passed to `receiver.add_tool(fn)`.
`tool-factory-registration`: parameters of a function passed to `receiver.tool()(fn)`.
`call-tool-arguments`: only the `arguments` parameter of a function decorated with
`receiver.call_tool(...)`. Standard taint propagation handles dictionary reads.

These are structural registration models, compatible with both MCP SDK FastMCP
and the standalone fastmcp package. Receiver identity is deliberately unconstrained
to cover imported server instances and parameters of registration wrappers.
Consequently a non-MCP API with the same registration spelling can also match.
Context parameters are not excluded by type. Function references for explicit
registration and wrapper activation use a separate global value-flow configuration.

A nested registration must occur in a statically activated scope. Module scopes
are active; class bodies inherit activation; function bodies become active through
a resolved call from an active scope. This is not full runtime reachability. Dynamic
startup callbacks, reflection, custom registration decorators, and registrations
inside externally invoked lifecycle handlers may remain unresolved.

## Sinks and propagation

All `Http::Client::Request.getAUrlPart()` nodes are sinks. These include the bundled
requests, httpx, aiohttp, urllib and urllib3 models and their modeled client objects.
A supplementary structural fallback recognizes HTTP verbs on common client field
names (`session`, `client`, `http_client`, `http`, `pool`) or local names (`session`,
`client`, `http_client`) only when that argument is not already a built-in URL sink.
Fallback names can match non-HTTP objects and are labeled `object-fallback.*`.
Round 2 also recognizes HTTP client parameter annotation terminal names through
local value flow, independently of the receiver variable name (`typed-client.*`).
Direct names, attributes and simple string annotations are supported. Package
identity and runtime types are not proven; union/container annotations and arbitrary
string type expressions are not modeled. Built-in sinks take precedence over this
supplement, and annotation hints take precedence over name-based fallback labels.

For httpx Client/AsyncClient and aiohttp ClientSession, `base_url` taints the
constructed client. A receiver sink is emitted only at an actual HTTP method call
associated with that constructor by the API graph (`client-base-url.*`). Merely
constructing a client is not a sink. This is a conservative base URL model; it does
not implement URL joining or absolute URL override semantics.

The main engine is `TaintTracking::Global`. No custom helper, collection or async
taint steps are added; those flows exercise the bundled engine. The only custom
flow step propagates `base_url` to its client constructor result. SSRF sanitizers
and barriers are intentionally absent.

## Guard indicator

`guard_seen=syntactic-route-hint` means at least one source-sink path-graph route
contains a function with a call using a common URL validation spelling. It does
not establish that every displayed route includes that function, that the call
validates the tainted URL, or that it dominates the sink. Helper functions are
included; validation spellings also include generic `validate*url` / `safe*url` forms.
`not-detected` means only that this limited heuristic found no hint; it does not
prove absence of a guard. Property-only guards and unknown spellings may be missed.
No safety or vulnerability verdict is assigned by this indicator.

## Results

The query is a single path-problem. Messages encode `source_kind`, `http_api` and
`guard_seen`, plus source and flow endpoint coordinates for unambiguous message
association. SARIF may group multiple paths into one result; the exporter preserves
every emitted thread flow. Path length counts displayed CodeQL nodes, including
endpoints, not runtime instructions. The CLI uses `--max-paths=20` per path alert;
location-grouped SARIF results can combine multiple
alerts. This is not an enumeration of all possible runtime paths.
