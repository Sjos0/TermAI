-- tests/validate_tmpdir_spec.lua — validate.test_connection não depende de /tmp (issue #131 / bug #130).
package.path = "./?.lua;./?/init.lua;" .. package.path
local validate = require("models.validate")

local pass, fail = 0, 0
local function T(name, ok, detail)
  if ok then
    pass = pass + 1
    print("  ✅ " .. name)
  else
    fail = fail + 1
    print("  ❌ " .. name .. (detail and (" — " .. tostring(detail)) or ""))
  end
end

-- Endpoint local com porta fechada: falha rápido, sem depender de rede ou DNS.
local ACTIVE = { endpoint = "http://127.0.0.1:9/v1/chat/completions", api_key = "", model_id = "m" }
local original_tmp_dir = validate.tmp_dir
-- Base gravável: TMPDIR do Termux, ou /tmp em ambientes como a CI.
local BASE = os.getenv("TMPDIR")
if BASE == nil or BASE == "" then BASE = "/tmp" end

print("\n=== 1. Código de produção sem os.tmpname ===")
do
  local f = io.open("models/validate.lua", "r")
  local src = f and f:read("*a") or ""
  if f then f:close() end
  T("models/validate.lua não usa os.tmpname()", src ~= "" and not src:find("os.tmpname", 1, true))
  T("models/validate.lua usa M.tmp_dir()", src:find("M.tmp_dir()", 1, true) ~= nil)
end

print("\n=== 2. Diretório não gravável: erro tratado, sem exceção ===")
do
  validate.tmp_dir = function() return "/proc" end
  local ok, res, msg = pcall(validate.test_connection, ACTIVE)
  T("test_connection não lança erro com diretório não gravável", ok == true, res)
  T("retorna false com mensagem de arquivo temporário", ok and res == false
    and tostring(msg):find("temporário", 1, true) ~= nil, msg)
end

print("\n=== 3. Caminho feliz: arquivo temporário é removido ===")
do
  local base = BASE
  validate.tmp_dir = function() return base end
  local ok, res = pcall(validate.test_connection, ACTIVE)
  T("test_connection executa até o curl com diretório gravável", ok == true and res == false, res)
  local h = io.popen("ls -A '" .. base .. "' 2>/dev/null")
  local listagem = h and h:read("*a") or ""
  if h then h:close() end
  T("nenhum termai_validate_* sobra no diretório", not listagem:find("termai_validate_", 1, true))
end

validate.tmp_dir = original_tmp_dir

print(string.format("\nRESULTADO (validate tmpdir): %d passaram, %d falharam", pass, fail))
if fail > 0 then os.exit(1) end
