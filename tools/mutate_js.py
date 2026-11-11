# Each mutation removes one model branch in a throwaway copy; a test must go red.
import shutil, subprocess, sys, pathlib, re
W = pathlib.Path(sys.argv[1]); C = str(pathlib.Path.home() / "tools/codeql-2.27.2/codeql/codeql")
src = (W / "js/McpSources.qll").read_text()
M = {
 "M1-fallback-yok": ("""    call = mcpServer().getMember(["tool", "registerTool"]).getACall()
    or
    call.(DataFlow::MethodCallNode)""", """    call = mcpServer().getMember(["tool", "registerTool"]).getACall()
    or
    none() and call.(DataFlow::MethodCallNode)"""),
 "M2-apigraph-yok": ("""    call = mcpServer().getMember(["tool", "registerTool"]).getACall()
    or""", """    none()
    or"""),
 "M3-fallback-import-sarti-yok": ("""    exists(Import i |
      i.getFile() = call.getFile() and i.getImportedPathString() = mcpServerModule()
    )""", "any()"),
 "M4-schema-capasi-yok": ("""      call.getArgument(0) =
        API::moduleImport(mcpTypesModule())
            .getMember("CallToolRequestSchema")
            .getAValueReachableFromSource() and""", ""),
 "M5-calltool-yok": ("  McpCallToolArguments() {\n", "  McpCallToolArguments() {\n    none() and\n"),
 "M6-vercel-yok": ("  UntypedVercelRequestInput() {\n", "  UntypedVercelRequestInput() {\n    none() and\n"),
 "M7-vercel-klasor-sarti-yok": ("""      m.getFile().getRelativePath().regexpMatch("(.*/)?api/.*") and""", ""),
 "M8-hono-yok": ("  HonoRequestInput() {\n", "  HonoRequestInput() {\n    none() and\n"),
 "M9-hono-metot-listesi-yok": ("""      call.getMethodName() = ["json", "query", "param"]""", "any()"),
}
for name, (a, b) in M.items():
    if sys.argv[2:] and name not in sys.argv[2:]: continue
    assert src.count(a) == 1, name
    d = W / "mutasyon" / name
    if d.exists(): shutil.rmtree(d)
    shutil.copytree(W, d, ignore=shutil.ignore_patterns("mutasyon", "*.testproj"))
    (d / "js/McpSources.qll").write_text(src.replace(a, b))
    r = subprocess.run([C, "test", "run", str(d / "js-test")], capture_output=True, text=True)
    diff = [l for l in r.stdout.splitlines() if re.match(r"^[+-]\|", l)]
    print(f"{name}: {'KIRMIZI' if r.returncode else 'YESIL (yasadi!)'}")
    for l in diff: print("   ", l)
    shutil.rmtree(d)
