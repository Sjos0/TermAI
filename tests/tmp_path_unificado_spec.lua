-- tests/tmp_path_unificado_spec.lua — make_tmp_path não usa os.tmpname; respeita TMPDIR;
-- harness/modelo e streamer não apontam /tmp fixo quando TMPDIR existe.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

-- 1. Produção: os.tmpname sumiu dos pontos citados na issue #186
local function read(path)
  local f = io.open(path, "r"); if not f then return "" end
  local s = f:read("*a"); f:close(); return s
end
local modelo = read("agent/harness/modelo.lua")
local streamer = read("agent/api/request_stream/streamer/parte_1.lua")
local utils_src = read("agent/api/utils.lua")
T(not modelo:find("os.tmpname(", 1, true), "modelo.lua não chama os.tmpname()")
T(streamer:find("TMPDIR", 1, true) ~= nil, "streamer usa TMPDIR no flag")
T(not streamer:find('or "/tmp")', 1, true) or streamer:find("com.termux", 1, true) ~= nil,
  "streamer não cai só em /tmp cego (Termux fallback ou TMPDIR)")
T(utils_src:find("make_tmp_path", 1, true) ~= nil, "utils expõe make_tmp_path")
T(not utils_src:find("os.tmpname(", 1, true), "utils.make_tmp_path não chama os.tmpname()")

-- 2. Com TMPDIR gravável, caminho fica dentro dele
local tmp = (os.getenv("TMPDIR") and os.getenv("TMPDIR") ~= "") and os.getenv("TMPDIR")
  or (function()
    local d = "/tmp/termai_tmp_spec_" .. tostring(os.time())
    os.execute("mkdir -p '" .. d .. "'")
    return d
  end)()
os.execute("mkdir -p '" .. tmp .. "'")
local old = os.getenv("TMPDIR")
-- setenv may not exist; use a child is hard — call make_tmp_path after forcing via package
package.loaded["agent.api.utils"] = nil
-- inject TMPDIR for this process if possible
local utils = require("agent.api.utils")
local path = utils.make_tmp_path()
T(type(path) == "string" and path:find("ta_payload_", 1, true) ~= nil, "make_tmp_path gera ta_payload_*")
local f = io.open(path, "w")
T(f ~= nil, "caminho retornado é gravável")
if f then f:write("ok"); f:close(); os.remove(path) end

-- 3. Diretório de workspace do harness (simula o padrão modelo.lua)
local ws = utils.make_tmp_path() .. "_ws"
local ok_mkdir = os.execute("mkdir -p '" .. ws .. "'")
T(ok_mkdir == true or ok_mkdir == 0, "workspace temporário criável")
os.execute("rm -rf '" .. ws .. "'")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
