-- tests/permissions_session_spec.lua — Testes unitários do módulo session (PR #33 / Issue #26)
package.path = "./?.lua;./?/init.lua;" .. package.path

local session = require("tools.exec.permissions.session")

local pass, fail = 0, 0
local function T(name, ok, detail)
  if ok then
    pass = pass + 1
    print("  ✅ " .. name)
  else
    fail = fail + 1
    print("  ❌ " .. name .. (detail and (" — " .. detail) or ""))
  end
end

local function sec(title)
  print("\n=== " .. title .. " ===")
end

-- Limpeza de estado entre seções (módulo usa tabela em memória)
local function clear_all()
  session.set_status("Exec", nil)
  session.set_status("Read", nil)
  session.set_status("Write", nil)
  session.set_rules("allow", {})
  session.set_rules("deny", {})
end

-- ============================================================================
-- 1. get_status / set_status
-- ============================================================================
sec("1. get_status / set_status")

clear_all()
T("get_status de tool não setada → nil", session.get_status("Exec") == nil)
T("get_status de outra tool não setada → nil", session.get_status("Read") == nil)

session.set_status("Exec", "always")
T("roundtrip set always / get", session.get_status("Exec") == "always")

session.set_status("Exec", "blocked")
T("roundtrip set blocked / get", session.get_status("Exec") == "blocked")

session.set_status("Read", "always")
T("tools são independentes (Exec ainda blocked)", session.get_status("Exec") == "blocked")
T("tools são independentes (Read = always)", session.get_status("Read") == "always")

session.set_status("Exec", nil)
T("set nil remove o status", session.get_status("Exec") == nil)

-- ============================================================================
-- 2. get_rules / set_rules
-- ============================================================================
sec("2. get_rules / set_rules")

clear_all()
T("get_rules('allow') vazio → {}", type(session.get_rules("allow")) == "table" and #session.get_rules("allow") == 0)
T("get_rules('deny') vazio → {}", type(session.get_rules("deny")) == "table" and #session.get_rules("deny") == 0)

session.set_rules("allow", {"echo *", "ls *"})
local allow = session.get_rules("allow")
T("roundtrip set_rules allow / get", #allow == 2 and allow[1] == "echo *" and allow[2] == "ls *")

session.set_rules("deny", {"rm *"})
local deny = session.get_rules("deny")
T("roundtrip set_rules deny / get", #deny == 1 and deny[1] == "rm *")

T("allow e deny são independentes (allow intacto)", #session.get_rules("allow") == 2)
T("allow e deny são independentes (deny intacto)", #session.get_rules("deny") == 1)

session.set_rules("allow", {})
T("set_rules({}) zera a lista", #session.get_rules("allow") == 0)
T("deny permanece após limpar allow", #session.get_rules("deny") == 1)

-- ============================================================================
-- 3. Isolamento entre status e rules
-- ============================================================================
sec("3. Isolamento status vs rules")

clear_all()
session.set_status("Exec", "blocked")
session.set_rules("deny", {"rm *"})
T("status não afeta rules", #session.get_rules("deny") == 1)
T("rules não afetam status", session.get_status("Exec") == "blocked")

clear_all()
print("\nRESULTADO: " .. pass .. " passaram, " .. fail .. " falharam")
if fail > 0 then os.exit(1) end
