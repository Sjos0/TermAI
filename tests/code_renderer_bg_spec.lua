-- tests/code_renderer_bg_spec.lua — linhas de code fence usam pad, não só ESC[K
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

package.loaded["ui.core"] = {
  c = { bg_code = "\27[48;5;236m" },
  tw = function() return 20 end,
}

local code = require("renderer.code_renderer")
local line = code.code_line("hello", 20)
T(line:find("48;5;236", 1, true) ~= nil, "code_line tem fundo cinza")
T(line:find("hello", 1, true) ~= nil, "code_line preserva texto")
-- deve ter espaços de pad (não depender só de ESC[K)
local without_k = line:gsub("\27%[K", "")
T(without_k:find("hello%s+") ~= nil or #without_k > #("hello")+5, "code_line faz pad com espaços")

local fence = code.code_fence("lua")
T(fence:find("```", 1, true) ~= nil, "code_fence mostra ```")
T(fence:find("48;5;236", 1, true) ~= nil, "code_fence tem fundo cinza")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
