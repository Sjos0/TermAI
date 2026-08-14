-- tests/permissions_denial_spec.lua — Testes unitários do módulo denial (PR #33 / Issue #26)
package.path = "./?.lua;./?/init.lua;" .. package.path

local denial = require("tools.exec.permissions.denial")

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

-- ============================================================================
-- 1. Contagem básica e reset
-- ============================================================================
sec("1. increment / get_count / reset")

denial.reset("toolA")
denial.reset("toolB")

T("get_count inicial → 0", denial.get_count("toolA") == 0)

local r1 = denial.increment("toolA")
T("1ª increment retorna false (não atingiu threshold)", r1 == false)
T("get_count após 1 → 1", denial.get_count("toolA") == 1)

local r2 = denial.increment("toolA")
T("2ª increment retorna false", r2 == false)
T("get_count após 2 → 2", denial.get_count("toolA") == 2)

-- ============================================================================
-- 2. Threshold padrão = 3 → retorna true e zera
-- ============================================================================
sec("2. Threshold padrão (3)")

denial.reset("toolA")
denial.increment("toolA")
denial.increment("toolA")
local r3 = denial.increment("toolA")
T("3ª increment retorna true (atingiu threshold)", r3 == true)
T("após threshold, contagem é zerada", denial.get_count("toolA") == 0)

local r4 = denial.increment("toolA")
T("próxima increment após reset automático → false", r4 == false)
T("get_count após 1 pós-reset → 1", denial.get_count("toolA") == 1)

-- ============================================================================
-- 3. Chaves independentes
-- ============================================================================
sec("3. Chaves independentes")

denial.reset("toolA")
denial.reset("toolB")
denial.increment("toolA")
denial.increment("toolA")
denial.increment("toolB")

T("toolA tem 2", denial.get_count("toolA") == 2)
T("toolB tem 1", denial.get_count("toolB") == 1)

denial.reset("toolA")
T("reset toolA zera só toolA", denial.get_count("toolA") == 0)
T("toolB permanece 1", denial.get_count("toolB") == 1)

-- ============================================================================
-- 4. reset explícito e novo ciclo de threshold
-- ============================================================================
sec("4. reset explícito + novo ciclo")

denial.reset("toolB")
denial.increment("toolB")
denial.increment("toolB")
T("toolB 3ª → true e zera", denial.increment("toolB") == true)
T("get_count toolB após threshold → 0", denial.get_count("toolB") == 0)

denial.increment("toolB")
denial.reset("toolB")
T("reset explícito zera", denial.get_count("toolB") == 0)

print("\nRESULTADO: " .. pass .. " passaram, " .. fail .. " falharam")
if fail > 0 then os.exit(1) end
