-- FASES 3 e 4 — fuzzy via fachada error_feedback e cenários reais de tool errada.
local harness = require("tests.helpers.harness")
local fuzzy = require("tools.error_feedback.fuzzy_match")
local error_feedback = require("tools.error_feedback.init")
local T, sec = harness.T_so_falhas, harness.sec

local M = {}

function M.run()
  ----------------------------------------------------------------------
  -- FASE 3: INTEGRAÇÃO — via error_feedback/init.lua
  ----------------------------------------------------------------------
  print("\n╔══════════════════════════════════════════════════╗")
  print("║  FASE 3: INTEGRAÇÃO — error_feedback            ║")
  print("╚══════════════════════════════════════════════════╝\n")

  -- 3.1: Acesso via fachada
  print("3.1 Acesso via fachada error_feedback")
  do
    local m, d = error_feedback.find_closest("exec", {"read", "exec", "write"})
    T("fachada: retorna resultado correto", m == "exec")
  end

  -- 3.2: Múltiplas chamadas (estabilidade)
  print("3.2 Estabilidade em múltiplas chamadas")
  do
    local results = {}
    for i = 1, 10 do
      local m, d = error_feedback.find_closest("edti", {"edit", "read", "exec", "write"})
      results[i] = m
    end
    local all_same = true
    for i = 2, 10 do
      if results[i] ~= results[1] then all_same = false; break end
    end
    T("10 chamadas idênticas: resultado determinístico", all_same)
  end

  -- 3.3: Funções da fachada não quebram
  print("3.3 Funções auxiliares da fachada")
  do
    local ok1 = pcall(function() error_feedback.detect_malformed_xml("<unclosed") end)
    T("detect_malformed_xml não crasha", ok1)

    local ok2 = pcall(function() error_feedback.accepts_empty_arg("exec") end)
    T("accepts_empty_arg não crasha", ok2)
  end

  ----------------------------------------------------------------------
  -- FASE 4: FLUXO — cenário real de uso
  ----------------------------------------------------------------------
  print("\n╔══════════════════════════════════════════════════╗")
  print("║  FASE 4: FLUXO — cenário real                   ║")
  print("╚══════════════════════════════════════════════════╝\n")

  -- Cenário: usuário digita "reed" em vez de "read"
  print("4.1 Usuário digita 'reed' em vez de 'read'")
  do
    local tools = {"exec", "read", "write", "edit", "grep", "find", "list"}
    local m, d = fuzzy.find_closest("reed", tools)
    T("typo 'reed' → 'read'", m == "read")
    T("distância ≤ 1", d <= 1)
  end

  -- Cenário: usuário digita "wrtie" em vez de "write"
  print("4.2 Usuário digita 'wrtie' em vez de 'write'")
  do
    local tools = {"exec", "read", "write", "edit", "grep", "find", "list"}
    local m, d = fuzzy.find_closest("wrtie", tools)
    T("typo 'wrtie' → 'write'", m == "write")
  end

  -- Cenário: usuário digita "grrep" em vez de "grep"
  print("4.3 Usuário digita 'grrep' em vez de 'grep'")
  do
    local tools = {"exec", "read", "write", "edit", "grep", "find", "list"}
    local m, d = fuzzy.find_closest("grrep", tools)
    T("typo 'grrep' → 'grep'", m == "grep")
  end

  -- Cenário: ferramenta completamente errada
  print("4.4 Ferramenta completamente errada")
  do
    local tools = {"exec", "read", "write", "edit", "grep", "find", "list"}
    local m, d = fuzzy.find_closest("banana", tools)
    T("ferramenta inexistente: nil ou distância alta", m == nil or d >= 4)
  end

  -- Cenário: lista grande de ferramentas (simula TermAI real)
  print("4.5 Lista realista de tools do TermAI")
  do
    local real_tools = {
      "exec", "read", "write", "edit", "grep", "find", "list",
      "memory_search", "web_fetch", "web_search", "restart",
      "session_status", "sessions_history", "sessions_list",
      "todo_write", "skill", "calculate"
    }
    local m, d = fuzzy.find_closest("rexec", real_tools)
    T("lista realista: encontra 'exec'", m == "exec")
  end
end

return M
