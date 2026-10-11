# Windows (native PowerShell)

Every rig script has a PowerShell twin next to it in `tools/rig/` — same arguments, same environment variables, same
output lines, same exit codes:

| bash | PowerShell | |
|---|---|---|
| `tools/rig/go.sh` | `tools\rig\go.ps1` | fast lane: build → shots → fast tests → publish if green → ui-map |
| `tools/rig/shot.sh` | `tools\rig\shot.ps1` | PC + phone rig screenshots |
| `tools/rig/fast.sh` | `tools\rig\fast.ps1` | STRICT guard tests + named tests |
| `tools/rig/run_all.sh` | `tools\rig\run_all.ps1` | full suite → `rc.txt` + logs |
| `tools/rig/compare_runs.sh` | `tools\rig\compare_runs.ps1` | rc / FAIL-count diff of two runs |
| `tools/rig/publish.sh` | `tools\rig\publish.ps1` | Open Cloud publish, 409 retry, `DRY_RUN=1` |
| `tools/rig/prices.sh` | `tools\rig\prices.ps1` | game pass / dev product price PATCH |
| `tools/rig/retention.sh` | `tools\rig\retention.ps1` | keep newest + 3 builds and LIVE |
| `tools/rig/config.sh` | `tools\rig\config.ps1` | shared settings (dot-sourced by the others) |
| `adapters/install.sh` | `adapters\install.ps1` | copy the skill into a game repo |

They run in **PowerShell 7 (`pwsh`)** and in the **Windows PowerShell 5.1** that ships with Windows. The Python tools
(`render.py`, `uimap_build.py`, `mcpc.py`) are plain cross-platform Python. Prefer pwsh 7 (`winget install
Microsoft.PowerShell`): it is faster to start and its web cmdlets behave better.

> Test status: the `.ps1` scripts were run with PowerShell 7.6 on Linux against a real place file (build, shots, fast
> tests, full suite, compare, retention, install, publish with `DRY_RUN=1`, and publish/prices against a local mock
> server for the 409 retry). They have **not** yet been run on a real Windows PC or under Windows PowerShell 5.1.
> If something breaks there, the troubleshooting section below lists the likely causes.

## 1. Install

### Git
`winget install Git.Git` (or https://git-scm.com/download/win). Git for Windows also gives you **Git Bash**, see §6.

### Python 3 + Pillow
1. `winget install Python.Python.3.12` (or the installer from https://www.python.org/downloads/windows/ — tick
   *Add python.exe to PATH*; the installer also adds the `py` launcher).
2. `py -3 -m pip install pillow`
3. Check: `py -3 -c "import PIL; print(PIL.__version__)"`

The scripts look for Python in this order: `$env:PYTHON` (a full path, if you set one) → `python` / `python3` on
PATH (the Microsoft Store stub that only opens the Store is detected and skipped) → `py -3`.

### Lune
Download from https://github.com/lune-org/lune/releases:
- `lune-0.8.9-windows-x86_64.zip` → unzip → put `lune.exe` at `tools\lune.exe` in your game repo (builds + tests;
  the reference project used 0.8.9).
- a 0.10.x zip (`lune-0.10.x-windows-x86_64.zip`, or `-aarch64` on ARM PCs) → rename to `tools\lune10.exe` (for
  place files saved by a recent Studio).

```powershell
cd C:\games\my-game
New-Item -ItemType Directory -Force tools | Out-Null
Invoke-WebRequest https://github.com/lune-org/lune/releases/download/v0.8.9/lune-0.8.9-windows-x86_64.zip -OutFile $env:TEMP\lune.zip
Expand-Archive $env:TEMP\lune.zip -DestinationPath $env:TEMP\lune -Force
Copy-Item $env:TEMP\lune\lune.exe tools\lune.exe
.\tools\lune.exe --version          # lune 0.8.9
```
If Windows SmartScreen or your antivirus blocks `lune.exe`, right-click → Properties → *Unblock*, or
`Unblock-File tools\lune.exe`.

### Install the skill into your game repo
```powershell
git clone https://github.com/<you>/roblox-agent-skill $HOME\roblox-agent-skill
& $HOME\roblox-agent-skill\adapters\install.ps1 C:\games\my-game claude codex antigravity cursor opencode
```
(`$env:FORCE='1'` to overwrite existing files.)

## 2. Execution policy
Windows blocks unsigned local scripts by default. Allow your own scripts once, for your user only:
```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```
Files downloaded from the internet (a zip from GitHub) carry a "Mark of the Web" and are still blocked under
RemoteSigned: `Get-ChildItem -Recurse tools, adapters | Unblock-File`. A `git clone` does not mark files.
One-off alternative without changing the policy: `pwsh -ExecutionPolicy Bypass -File tools\rig\go.ps1 ...`.

## 3. Environment variables
Bash's `VAR=1 cmd` has no direct PowerShell form. Set the variable for the session, run, then clear it:
```powershell
$env:GAME_DIR = 'games\my-game'                 # this session only
$env:NOPUBLISH = '1'; .\tools\rig\go.ps1 v145 open=ShopFrame; Remove-Item Env:NOPUBLISH
```
Persistent (new terminals only; does **not** change the current one):
```powershell
setx UNIVERSE_ID <your-universe-id>
setx PLACE_ID <your-place-id>
```
**The API key:** `setx` stores it in plain text in your user registry hive. Acceptable on a personal PC; better is a
git-ignored file you load per session:
```powershell
# .env.ps1 (add it to .gitignore - install.ps1 already ignores .env)
$env:ROBLOX_API_KEY = '<your Open Cloud key>'      # NEVER commit, paste in chat, or log it
$env:UNIVERSE_ID = '<your-universe-id>'; $env:PLACE_ID = '<your-place-id>'
```
then `. .\.env.ps1` at the start of a session. Add `.env.ps1` to `.gitignore`.

All rig variables: `GAME_DIR` (default `games\my-game`), `LUNE` (`tools\lune.exe`), `LUNE_NEW` (`tools\lune10.exe`),
`TESTS`, `XDIR` (`work\x`), `RIG_OUT` (`work\rig\out`), `CANON`, `FAST_TESTS`, `PC_W/PC_H`, `PHONE_W/PHONE_H`,
`ROBLOX_API_KEY`, `UNIVERSE_ID`, `PLACE_ID`, `VERSION_TYPE` (Published|Saved), `DRY_RUN`, `NOPUBLISH`, `STRICT`,
`BASELINE`, `DRY` (retention), `PYTHON`, `RIG_FONT` (TTF used by `render.py`; default Arial Bold on Windows).
Lune tests read `STRICT` / `BASELINE` / `FAST` themselves; `fast.ps1` sets `STRICT=1` for the guard tests, exactly
like `fast.sh`.

## 4. The fast lane in PowerShell (full walkthrough)
Run from the game repo root. First time, with the bundled example game and any place file of yours:
```powershell
cd C:\games\my-game
$env:GAME_DIR = 'tools\example-game'
$env:BASE = 'C:\path\to\your-place.rbxl'

# 1. build: base place + the example hook -> work\x\t1.rbxl
New-Item -ItemType Directory -Force work\x | Out-Null
$env:BUILD_OUT = 'work\x\t1.rbxl'; .\tools\lune.exe run tools\example-game\build.luau; Remove-Item Env:BUILD_OUT

# 2. guard + feature tests (first run writes the guard baselines into tools\example-game\tests\data\)
.\tools\rig\fast.ps1 work\x\t1.rbxl example_feature_test
#   fast PASS: 3 pass / 0 fail | example_feature_test:ok studio_rule_test:ok text_size_test:ok  (0.9 s, logs work\rig\out\fast)

# 3. rig screenshots -> work\rig\out\t1_pc.png + t1_phone.png  (open both and LOOK)
.\tools\rig\shot.ps1 work\x\t1.rbxl t1
Invoke-Item work\rig\out\t1_pc.png; Invoke-Item work\rig\out\t1_phone.png

# 4. the whole lane in one command, publish only rehearsed
$env:DRY_RUN = '1'; .\tools\rig\go.ps1 t2 example_feature_test; Remove-Item Env:DRY_RUN
#   fast PASS ... / shots: work\rig\out\t2_pc.png work\rig\out\t2_phone.png / DRY_RUN: would POST ... / total 3 s
```
Day to day, on your own game (`$env:GAME_DIR` pointing at it, key loaded):
```powershell
.\tools\rig\go.ps1 v145 open=ShopFrame                       # build, shots, tests, publish if green
$env:NOPUBLISH = '1'; .\tools\rig\go.ps1 v145 open=ShopFrame  # hold before publishing (owner looks first)
.\tools\rig\publish.ps1 work\x\v145.rbxl                       # publish a build you already checked
```
Gameplay lane (full suite + comparison against the base build):
```powershell
.\tools\rig\run_all.ps1 work\x\v144.rbxl work\logs\v144
.\tools\rig\run_all.ps1 work\x\v145.rbxl work\logs\v145
.\tools\rig\compare_runs.ps1 work\logs\v144 work\logs\v145
```
Other tools:
```powershell
.\tools\rig\prices.ps1 pass 123456 199              # owner's explicit number only
$env:DRY = '1'; .\tools\rig\retention.ps1; Remove-Item Env:DRY
py -3 tools\uimap\uimap_build.py work\x\v145.rbxl   # regenerate ui-map.md
```
Exit codes match bash: `0` ok, `1` failure (build/tests/publish/usage), `2` missing place or unknown test.
In a script, check `$LASTEXITCODE` after each call.

## 5. Roblox Studio MCP on Windows
Studio's built-in MCP server (Assistant → ⋯ → *Manage MCP Servers* → *Enable Studio as MCP server*) is started
through `%LOCALAPPDATA%\Roblox\mcp.bat` (PowerShell: `"$env:LOCALAPPDATA\Roblox\mcp.bat"`; check it exists with
`Test-Path "$env:LOCALAPPDATA\Roblox\mcp.bat"`).
- Agent on the same PC (Claude Code, Codex CLI, Cursor, Gemini CLI): stdio command `cmd.exe /c
  %LOCALAPPDATA%\Roblox\mcp.bat` — already in `adapters/claude-code/.mcp.json` and
  `adapters/codex/config.toml.example`. Studio's *Quick connect* buttons can set this up for supported agents.
- Agent elsewhere (cloud): wrap it as HTTP and tunnel it (docs/studio-mcp-bridge.md):
  ```powershell
  npx -y supergateway --stdio "cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat" --outputTransport streamableHttp --port 8000
  cloudflared tunnel --url http://localhost:8000      # second window; share the https://...trycloudflare.com URL + /mcp
  ```
- Client from PowerShell: `$env:STUDIO_MCP_URL = 'https://<words>.trycloudflare.com/mcp'; py -3 tools\mcp\mcpc.py tools`

## 6. Optional: Git Bash or WSL instead
- **Git Bash** (comes with Git for Windows): the `.sh` scripts can work there, with caveats: set
  `export LUNE=tools/lune.exe`; the scripts call `python3`, which a python.org install does not provide (an
  alias is not seen by scripts — put a `python3` shim on PATH or install Python from the Microsoft Store);
  `timeout`, `realpath -m` and `date +%s.%N` come from Git's MSYS tools and generally work. Untested here — the `.ps1`
  scripts avoid all of this.
- **WSL 2** (`wsl --install`, then Ubuntu): a real Linux, the `.sh` scripts run unchanged. Use the **Linux** Lune
  build inside WSL (`lune-0.8.9-linux-x86_64.zip`), `sudo apt install python3-pil`, and keep the repo inside the WSL
  filesystem (`~/games/...`) — working on `/mnt/c/...` is several times slower. Studio still runs on Windows; reach
  its MCP from WSL through the HTTP bridge above (with WSL's mirrored networking `http://localhost:8000/mcp`
  works; otherwise use the Windows host IP or the cloudflared URL).

## 7. Troubleshooting
| Symptom | Cause / fix |
|---|---|
| `... cannot be loaded because running scripts is disabled on this system` | Execution policy → §2. |
| `... is not digitally signed` | Downloaded files are marked: `Unblock-File` (§2). |
| `fast.ps1: no place work\x\t1.rbxl` / `BUILD FAIL` | Run from the game repo root; check `$env:GAME_DIR` and `$env:BASE`; read `work\x\<name>.build.log`. |
| `The term 'tools\lune.exe' is not recognized` / Start-Process cannot find the file | `lune.exe` missing or elsewhere: put it at `tools\lune.exe` or `$env:LUNE = 'C:\path\lune.exe'`. |
| Shots missing, `render.log` says `No module named 'PIL'` | `py -3 -m pip install pillow` for the same Python the script picks (set `$env:PYTHON` to be sure). |
| `python` opens the Microsoft Store | Disable *App execution aliases* for python in Windows Settings, or install python.org Python; the scripts already skip the stub and fall back to `py -3`. |
| Text in shots looks different from Linux shots | Different font (Arial Bold vs DejaVu). Set `$env:RIG_FONT` to the same TTF on every machine for identical renders. Shots are rig approximations either way, never "verified on phone". |
| `shot.ps1: dump failed` | Your `tools\rig\dump.luau` boot section does not match your game; read `work\rig\out\<name>_pc\dump.log`. Unknown `key=value` args go to the dump (as in bash). |
| `publish try 1: HTTP 401/403` | Key wrong, expired, missing `universe-places:write`, or its IP allow-list excludes this PC. |
| `HTTP 404` on publish | Universe / place IDs do not belong together. |
| `HTTP 000 ...` | No network or TLS problem; on Windows PowerShell 5.1 the script enables TLS 1.2 itself, check a proxy. |
| `publish try N: HTTP 409` ×4 | Someone (Studio, another publish) holds the place; wait and retry. |
| Garbled characters in logs | Logs are UTF-8; open them in VS Code / Notepad, or `Get-Content -Encoding utf8` in 5.1. |
| Paths with spaces | Supported; quote them: `.\tools\rig\fast.ps1 "work\x\my build.rbxl"`. |
| Antivirus slows every Lune start | Exclude the repo folder (and `tools\lune.exe`) from real-time scanning. |
| `setx` value not visible | `setx` only affects new terminals; use `$env:NAME = ...` in the current one. |
| Lines end with CRLF after checkout and a Luau file misbehaves | `git config core.autocrlf false` in the game repo (Lune handles CRLF, but diffs get noisy). |
