r"""Minimal client for a Roblox Studio MCP server exposed over HTTP (streamable-HTTP MCP).

Setup (on the owner's PC, where Studio runs; see docs/studio-mcp-bridge.md):
  1. Studio has a BUILT-IN MCP server (Assistant > ... > Manage MCP Servers > "Enable Studio as MCP server").
     It speaks stdio: Windows `cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat`, macOS `/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP`.
     If your agent runs ON that PC (Claude Code, Codex CLI, Cursor, Gemini CLI...), connect it directly over stdio; you do not need this file.
  2. If your agent runs in the cloud / another machine, wrap stdio as HTTP on the PC:
       npx -y supergateway --stdio "cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat" --outputTransport streamableHttp --port 8000
  3. Expose it (quick, no account):  cloudflared tunnel --url http://localhost:8000
     -> prints https://<random-words>.trycloudflare.com ; the MCP endpoint is that URL + /mcp
  The URL changes every time the tunnel restarts: the owner pastes the new link, you set STUDIO_MCP_URL.
  Anyone with the URL can drive Studio: share it only with the agent, kill the tunnel when done.

usage:
  export STUDIO_MCP_URL=https://<random-words>.trycloudflare.com/mcp
  python3 tools/mcp/mcpc.py tools                      # list tools the server offers
  (Windows PowerShell: $env:STUDIO_MCP_URL='https://.../mcp'; py -3 tools\mcp\mcpc.py tools   - see docs/windows.md)
  python3 tools/mcp/mcpc.py lua probe.luau             # run a Luau file in Studio (Edit datamodel)
  python3 tools/mcp/mcpc.py call list_roblox_studios '{}'   # find the studio_id
  STUDIO_ID=<id> python3 tools/mcp/mcpc.py lua probe.luau Client   # run in the Play client (Server for the Play server)

Rules that bit us (docs/lessons-learned.md):
  * one call ~30 s max: split big probes, return short strings (JSON-encode tables yourself).
  * screen captures can be STALE: measure (AbsoluteSize/AbsolutePosition/Visible) instead of trusting a picture.
  * close open menus before clicking/capturing; a menu left open hides what you test next.
  * the Edit datamodel is the owner's file: read freely, but WRITE only with the owner's OK (it is his live project).
"""
import json, os, sys, urllib.request

URL = os.environ.get("STUDIO_MCP_URL", "")
H = {"Content-Type": "application/json", "Accept": "application/json, text/event-stream"}


def rpc(method, params, i=1, sid=None, timeout=60):
    if not URL:
        raise SystemExit("set STUDIO_MCP_URL (tunnel URL + /mcp)")
    h = dict(H)
    if sid:
        h["Mcp-Session-Id"] = sid
    req = urllib.request.Request(URL, json.dumps({"jsonrpc": "2.0", "id": i, "method": method, "params": params}).encode(), h)
    r = urllib.request.urlopen(req, timeout=timeout)
    body = r.read().decode('utf-8', errors='replace')
    for line in body.splitlines():  # SSE framing: keep the last data: line
        if line.startswith("data:"):
            body = line[5:]
    return json.loads(body), r.headers.get("Mcp-Session-Id")


def session():
    _, sid = rpc("initialize", {"protocolVersion": "2025-03-26", "capabilities": {}, "clientInfo": {"name": "agent", "version": "1"}})
    return sid


def call(tool, args):
    sid = session()
    res, _ = rpc("tools/call", {"name": tool, "arguments": args}, 2, sid)
    if "error" in res:
        return "MCP ERROR: " + json.dumps(res["error"])[:800]
    return "".join(c.get("text", "") for c in res.get("result", {}).get("content", [])) or json.dumps(res)[:800]


def tools():
    sid = session()
    res, _ = rpc("tools/list", {}, 2, sid)
    return [t["name"] for t in res.get("result", {}).get("tools", [])]


def lua(code, dm="Edit"):
    """Run Luau in Studio. Argument names differ between MCP server versions: check `tools` output / schema."""
    args = {"code": code, "datamodel_type": dm}  # built-in server: datamodel_type Edit | Client | Server
    if os.environ.get("STUDIO_ID"):  # every built-in tool takes studio_id; get it from `list_roblox_studios`
        args["studio_id"] = os.environ["STUDIO_ID"]
    return call(os.environ.get("STUDIO_EXEC_TOOL", "execute_luau"), args)


if __name__ == "__main__":
    for _s in (sys.stdout, sys.stderr):  # Windows consoles (cp1252/cp850) cannot print every character Studio returns
        try: _s.reconfigure(errors="replace")
        except (AttributeError, ValueError): pass
    if len(sys.argv) >= 2 and sys.argv[1] == "tools":
        print("\n".join(tools()))
    elif len(sys.argv) >= 3 and sys.argv[1] == "call":
        print(call(sys.argv[2], json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}))
    elif len(sys.argv) >= 3 and sys.argv[1] == "lua":
        print(lua(open(sys.argv[2], encoding="utf-8").read(), sys.argv[3] if len(sys.argv) > 3 else "Edit"))
    else:
        print(__doc__)
