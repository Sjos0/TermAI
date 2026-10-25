-- tests/helpers/harness.lua — Placar e T/sec compartilhados pelos specs divididos.
-- Cada submódulo de tests/<spec>/ soma no mesmo placar, e a fachada imprime o total.
local M = { pass = 0, fail = 0, skip = 0 }

-- Checagem: ✅ passa; ❌ falha, com detalhe opcional.
function M.T(name, ok, detail)
  if ok then
    M.pass = M.pass + 1
    print("  ✅ " .. name)
  else
    M.fail = M.fail + 1
    print("  ❌ " .. name .. (detail and (" — " .. detail) or ""))
  end
end

-- Variante silenciosa: não imprime os passos; só mostra "FAIL: ..." quando falha.
function M.T_so_falhas(name, ok, detail)
  if ok then
    M.pass = M.pass + 1
  else
    M.fail = M.fail + 1
    print("  FAIL: " .. name .. (detail and (" — " .. tostring(detail)) or ""))
  end
end

-- Título de seção.
function M.sec(title)
  print("\n=== " .. title .. " ===")
end

return M
