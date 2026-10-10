-- Example Studio probe (run with: python3 tools/mcp/mcpc.py lua tools/mcp/probe_ui.luau Client)
-- MEASURE instead of trusting a screenshot: returns size/position/visibility/text size of a UI element in the running client.
-- Keep the output short (one JSON string); the MCP call times out around 30 s.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local lp = Players.LocalPlayer
if not lp then return "no LocalPlayer (run in a Play client, not Edit)" end
local gui = lp:WaitForChild("PlayerGui", 5)
local target = gui and gui:FindFirstChild("MainUI") and gui.MainUI:FindFirstChild("DropButton", true)
if not target then return "DropButton not found" end
local cam = workspace.CurrentCamera
local out = {
	viewport = { cam.ViewportSize.X, cam.ViewportSize.Y },
	visible = target.Visible,
	absSize = { target.AbsoluteSize.X, target.AbsoluteSize.Y },
	absPos = { target.AbsolutePosition.X, target.AbsolutePosition.Y },
	onScreen = target.AbsolutePosition.X >= 0 and target.AbsolutePosition.Y >= 0
		and target.AbsolutePosition.X + target.AbsoluteSize.X <= cam.ViewportSize.X
		and target.AbsolutePosition.Y + target.AbsoluteSize.Y <= cam.ViewportSize.Y,
	texts = {},
}
for _, d in target:GetDescendants() do
	if d:IsA("TextLabel") or d:IsA("TextButton") then
		table.insert(out.texts, { d.Name, d.Text, d.TextBounds.Y, d.TextScaled, d.TextWrapped })
	end
end
return HttpService:JSONEncode(out)
