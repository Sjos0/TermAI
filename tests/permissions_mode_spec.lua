-- tests/permissions_mode_spec.lua — Testes unitários do módulo mode (PR #33 / Issue #26)
-- ATENÇÃO: toca config.json (defaultMode); sempre restaura o original.
package.path = "./?.lua;./?/init.lua;" .. package.path

local mode = require("tools.exec.permissions.mode")
local config_mod = require("config")

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

local orig_mode = mode.get()

-- ============================================================================
-- 1. get / set
-- ============================================================================
sec("1. get / set")

T("get() retorna string", type(mode.get()) == "string")
T("get() retorna lowercase", mode.get() == mode.get():lower())

mode.set("bypass")
T("set('bypass') → get() == 'bypass'", mode.get() == "bypass")

mode.set("acceptEdits")
T("set('acceptEdits') → get() lowercase", mode.get() == "acceptedits")

mode.set("default")
T("set('default') → get() == 'default'", mode.get() == "default")

local cfg = config_mod.load()
T("set persiste em config.json", (cfg.permissions and cfg.permissions.defaultMode or ""):lower() == "default")

-- ============================================================================
-- 2. command_exists
-- ============================================================================
sec("2. command_exists")

T("command_exists('echo') == true", mode.command_exists("echo") == true)
T("command_exists('') == true (vazio é tratado como true)", mode.command_exists("") == true)
T("command_exists(nil) == true", mode.command_exists(nil) == true)
T("command_exists('nome_que_nao_existe_xyz_12345') == false", mode.command_exists("nome_que_nao_existe_xyz_12345") == false)
T("command_exists('ls') == true", mode.command_exists("ls") == true)

-- Cleanup: restaura modo original
mode.set(orig_mode)
T("modo original restaurado", mode.get() == orig_mode:lower())

print("\nRESULTADO: " .. pass .. " passaram, " .. fail .. " falharam")
if fail > 0 then os.exit(1) end
