# Each mutation removes one model branch in a throwaway copy; a test must go red.
import shutil, subprocess, sys, pathlib, re
W = pathlib.Path(sys.argv[1]); C = str(pathlib.Path.home() / "tools/codeql-2.27.2/codeql/codeql")
LANG = "py"
src = (W / f"{LANG}/McpSources.qll").read_text()
M = {
 "P1-apigraph-yok": ("""    d = mcpServer().getMember(kind).getAValueReachableFromSource().asExpr()
    or
    d = mcpServer().getMember(kind).getACall().asExpr()
    or""", """    none()
    or"""),
 "P2-fallback-yok": ("""    exists(Attribute a |
      a.getName() = kind and""", """    none() and exists(Attribute a |
      a.getName() = kind and"""),
 "P3-fallback-import-sarti-yok": ("""      importsMcp(d.getLocation().getFile()) and
      (d = a""", """      (d = a"""),
 "P4-import-tam-ad-degil-onek": ('regexpMatch("(mcp|fastmcp)(\\\\..*)?")', 'regexpMatch("(mcp|fastmcp).*")'),
 "P5-context-dislama-yok": ("      not isContextParam(p)\n", "      any()\n"),
 "P6-calltool-name-siniri-yok": ('(p.getName() = "arguments" or p = f.getArg(1) and not f.isMethod())', 'p = f.getAnArg()'),
 "P7-add-tool-yok": ("""  kind = "tool" and
  exists(Call c, Expr arg |""", """  none() and kind = "tool" and
  exists(Call c, Expr arg |"""),
 "P8-calltool-sinifi-yok": ("  McpCallToolArguments() {\n", "  McpCallToolArguments() {\n    none() and\n"),
 "P9-kwarg-vararg-yok": (" or p = f.getKwarg() or p = f.getVararg()", ""),
}
for name, (a, b) in M.items():
    if sys.argv[2:] and name not in sys.argv[2:]: continue
    assert src.count(a) == 1, name
    d = W / "mutasyon" / name
    if d.exists(): shutil.rmtree(d)
    shutil.copytree(W, d, ignore=shutil.ignore_patterns("mutasyon", "*.testproj"))
    (d / f"{LANG}/McpSources.qll").write_text(src.replace(a, b))
    r = subprocess.run([C, "test", "run", str(d / f"{LANG}-test")], capture_output=True, text=True)
    diff = [l for l in r.stdout.splitlines() if re.match(r"^[+-]\|", l)]
    print(f"{name}: {'KIRMIZI' if r.returncode else 'YESIL (yasadi!)'}")
    for l in diff: print("   ", l)
    shutil.rmtree(d)
