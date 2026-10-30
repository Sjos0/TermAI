-- tests/retry_linhas_fisicas_spec.lua — #203: clear com emoji; show_api_error permanente
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

package.loaded["ui.core"] = {
  c = {
    reset="\27[0m", gray="\27[38;5;245m", orange="\27[38;5;208m",
    bg_error="\27[48;5;52m", bg="\27[48;5;234m",
  },
  tw = function() return 24 end,
}

local writes = {}
local real_write = io.write
io.write = function(...)
  writes[#writes + 1] = table.concat({...})
  return real_write(...)
end

package.loaded["ui.spinner.retry"] = nil
local retry = require("ui.spinner.retry")

local emoji_msg = "falha " .. string.char(0xE2,0x9C,0x85):rep(3) -- fallback; use literal
emoji_msg = "falha ✅✅✅"

writes = {}
retry.show_retry(1, 5, emoji_msg, 1)
local after_show = table.concat(writes)
T(after_show:find("Tentativa 1/5", 1, true) ~= nil, "pintou card")

writes = {}
retry.clear_retry_lines()
local after_clear = table.concat(writes)
T(after_clear:find("\27[", 1, true) ~= nil or after_clear:find("\27", 1, true) ~= nil,
  "clear emite ESC para apagar")
T(after_clear:match("\27%[(%d+)A") ~= nil, "clear sobe N linhas")

-- show_api_error permanente: clear nao apaga depois
writes = {}
retry.show_api_error("fim " .. emoji_msg)
local err_out = table.concat(writes)
T(err_out:find("[ERRO]", 1, true) ~= nil or err_out:find("ERRO", 1, true) ~= nil, "api_error desenhou")
writes = {}
retry.clear_retry_lines()
local after_err_clear = table.concat(writes)
T(after_err_clear == "" or not after_err_clear:find("%d+A"),
  "clear apos api_error nao sobe (permanente, n=0)")

io.write = real_write
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
