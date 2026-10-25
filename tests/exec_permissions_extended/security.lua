-- Seções 1-3 de exec_permissions_extended: comandos destrutivos, paths sensíveis e edge cases de segurança.
local harness = require("tests.helpers.harness")
local security = require("tools.exec.security")
local T, sec = harness.T, harness.sec

local M = {}

function M.run()
  -- ============================================================================
  -- 1. SECURITY.LUA — COMANDOS DESTRUTIVOS ADICIONAIS
  -- ============================================================================
  sec("1. Comandos Destrutivos Adicionais")

  local rmdir_res = security.analyze("rmdir /tmp/test")
  T("Detecta 'rmdir'", rmdir_res.safe == false and rmdir_res.severity == "high")

  local mkfs_res = security.analyze("mkfs.ext4 /dev/sda1")
  T("Detecta 'mkfs'", mkfs_res.safe == false and mkfs_res.severity == "high")

  local dd_res = security.analyze("dd if=/dev/zero of=/dev/sda")
  T("Detecta 'dd'", dd_res.safe == false and dd_res.severity == "high")

  local shutdown_res = security.analyze("shutdown -h now")
  T("Detecta 'shutdown'", shutdown_res.safe == false and shutdown_res.severity == "high")

  local shred_res = security.analyze("shred -vfz /tmp/secret.txt")
  T("Detecta 'shred'", shred_res.safe == false and shred_res.severity == "high")


  -- ============================================================================
  -- 2. SECURITY.LUA — PATHS SENSÍVEIS ADICIONAIS
  -- ============================================================================
  sec("2. Paths Sensíveis Adicionais")

  local shadow_res = security.analyze("cat /etc/shadow")
  T("Detecta '/etc/shadow'", shadow_res.safe == false and shadow_res.severity == "high")

  local sudoers_res = security.analyze("cat /etc/sudoers")
  T("Detecta '/etc/sudoers'", sudoers_res.safe == false and sudoers_res.severity == "high")

  local proc_res = security.analyze("cat /proc/sys/kernel/hostname")
  T("Detecta '/proc/sys'", proc_res.safe == false and proc_res.severity == "high")


  -- ============================================================================
  -- 3. SECURITY.LUA — EDGE CASES
  -- ============================================================================
  sec("3. Edge Cases de Segurança")

  local nil_res = security.analyze(nil)
  T("Comando nil é seguro", nil_res.safe == true and nil_res.severity == "low")

  local whitespace_res = security.analyze("   ")
  T("Comando só whitespace é seguro", whitespace_res.safe == true and whitespace_res.severity == "low")

  -- Múltiplos warnings no mesmo comando
  local multi_res = security.analyze("rm -rf /tmp; cat /etc/passwd")
  T("Múltiplos warnings detectados (destructive + traversal)", 
    multi_res.safe == false and multi_res.severity == "high" and #multi_res.warnings >= 2)

  -- Campo safety_level no retorno
  local level_res = security.analyze("ls")
  T("Retorno contém campo safety_level", level_res.safety_level ~= nil)
end

return M
