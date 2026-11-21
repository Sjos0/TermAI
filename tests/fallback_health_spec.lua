package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local health = require("commands.config.fallback_health")
local pass, fail = 0, 0
local function T(name, ok)
  if ok then pass = pass + 1; print("  PASS " .. name)
  else fail = fail + 1; print("  FAIL " .. name) end
end

T("failure timestamp is compact and explicitly UTC",
  health.label({ last_error_at = "2026-11-21T11:15:42Z" })
    == "  [última falha: 21/11/2026 11:15 UTC]")
T("success timestamp is compact and explicitly UTC",
  health.label({ last_ok = "2026-11-20T08:09:10Z" })
    == "  [último OK: 20/11/2026 08:09 UTC]")
T("missing health stays untested", health.label({}) == "  [sem teste]")
T("failure takes precedence over success",
  health.label({ last_error_at = "2026-11-21T11:15:42Z", last_ok = "old" })
    == "  [última falha: 21/11/2026 11:15 UTC]")
T("unknown timestamp formats remain visible",
  health.label({ last_ok = "legacy-value" }) == "  [último OK: legacy-value]")
T("provider errors are flattened to one line",
  health.sanitize_message("quota\nexceeded") == "quota exceeded")
T("provider errors cannot inject ANSI screen controls",
  health.sanitize_message("bad\27[2Jerror") == "baderror")
T("provider error SGR colors are removed",
  health.sanitize_message("\27[31mdenied\27[0m") == "denied")
T("provider error extended SGR controls are removed",
  health.sanitize_message("\27[31:1mdenied\27[0m") == "denied")
T("provider error OSC title controls are removed",
  health.sanitize_message("bad\27]0;fake title\7error") == "baderror")
T("provider error DCS controls are removed",
  health.sanitize_message("bad\27Ppayload\27\\error") == "baderror")
T("provider error redacts the API key",
  health.error_message("quota: secret-token", "secret-token") == "quota: [REDACTED]")
T("provider error sanitizes controls before redacting the API key",
  health.error_message("quota: sec\27[31mret-token", "secret-token")
    == "quota: [REDACTED]")
T("provider error safely redacts punctuation in API keys",
  health.error_message("invalid key: a.b+c", "a.b+c") == "invalid key: [REDACTED]")

print(string.format("\nFALLBACK HEALTH: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
