-- FASE 1 — fuzzy_match.lua direto: match exato, case, erros pequenos e grandes, thresholds e edge cases.
local harness = require("tests.helpers.harness")
local fuzzy = require("tools.error_feedback.fuzzy_match")
local T, sec = harness.T_so_falhas, harness.sec

local M = {}

function M.run()
  ----------------------------------------------------------------------
  -- FASE 1: ISOLAMENTO — fuzzy_match.lua direto
  ----------------------------------------------------------------------
  print("\n╔══════════════════════════════════════════════════╗")
  print("║  FASE 1: ISOLAMENTO — fuzzy_match.lua           ║")
  print("╚══════════════════════════════════════════════════╝\n")

  -- 1.1: Match exato
  print("1.1 Match exato")
  do
    local m, d = fuzzy.find_closest("exec", {"read", "exec", "write"})
    T("match exato: retorna o nome correto", m == "exec")
    T("match exato: distância = 0", d == 0)
  end

  -- 1.2: Match case-insensitive
  print("1.2 Match case-insensitive")
  do
    local m, d = fuzzy.find_closest("EXEC", {"read", "exec", "write"})
    T("case-insensitive: encontra 'exec'", m == "exec")
    T("case-insensitive: distância = 0", d == 0)
  end

  -- 1.3: Match com erro pequeno (1 char)
  print("1.3 Match com erro pequeno")
  do
    local m, d = fuzzy.find_closest("exe", {"read", "exec", "write"})
    T("1 char a menos: encontra 'exec'", m == "exec")
    T("1 char a menos: distância = 1", d == 1)
  end

  -- 1.4: Match com erro maior (2 chars)
  print("1.4 Match com erro maior")
  do
    local m, d = fuzzy.find_closest("exac", {"read", "exec", "write"})
    T("2 chars diferentes: encontra 'exec'", m == "exec")
    T("2 chars diferentes: distância correta", d >= 1 and d <= 3)
  end

  -- 1.5: Sem match (acima do threshold)
  print("1.5 Sem match (acima do threshold)")
  do
    local m, d = fuzzy.find_closest("xyz", {"read", "exec", "write"})
    T("input muito diferente: match fraco ou nil", m == nil or d >= 3)
  end

  -- 1.6: Input vazio
  print("1.6 Input vazio")
  do
    local m, d = fuzzy.find_closest("", {"read", "exec", "write"})
    T("input vazio: retorna nil", m == nil)
  end

  -- 1.7: Input nil
  print("1.7 Input nil")
  do
    local m, d = fuzzy.find_closest(nil, {"read", "exec", "write"})
    T("input nil: retorna nil", m == nil)
  end

  -- 1.8: Candidates vazio
  print("1.8 Candidates vazio")
  do
    local m, d = fuzzy.find_closest("exec", {})
    T("candidates vazio: retorna nil", m == nil)
    T("candidates vazio: distância = huge", d == math.huge)
  end

  -- 1.9: Múltiplos candidatos similares
  print("1.9 Múltiplos candidatos similares")
  do
    local m, d = fuzzy.find_closest("exec", {"execution", "executor", "exec", "excess"})
    T("múltiplos similares: prefere o exato", m == "exec")
    T("múltiplos similares: distância = 0", d == 0)
  end

  -- 1.10: Case sensitive primário
  print("1.10 Case sensitive primário")
  do
    local m, d = fuzzy.find_closest("exec", {"Exec", "EXEC", "exec"})
    T("case sensitive: encontra match", m ~= nil)
  end

  -- 1.11: Candidatos com caracteres especiais
  print("1.11 Caracteres especiais")
  do
    local m, d = fuzzy.find_closest("grep", {"grep", "egrep", "fgrep", "pgrep"})
    T("caracteres normais: encontra 'grep'", m == "grep")
  end

  -- 1.12: Input muito longo
  print("1.12 Input longo")
  do
    local long_input = string.rep("a", 100)
    local m, d = fuzzy.find_closest(long_input, {"a", "bb", "ccc"})
    T("input longo: não crasha", m ~= nil or d > 5)
  end

  -- 1.13: Candidatos com strings idênticas
  print("1.13 Duplicatas")
  do
    local m, d = fuzzy.find_closest("exec", {"exec", "exec", "exec"})
    T("duplicatas: retorna match", m == "exec")
  end

  -- 1.14: Threshold exato (distância = 5)
  print("1.14 Threshold exato")
  do
    -- "abcde" vs "fghij" = distância 5 (cada char diferente)
    local m, d = fuzzy.find_closest("abcde", {"fghij"})
    T("distância = 5 (threshold): resultado válido", m == nil or d >= 5)
  end

  -- 1.15: Distância = 4 (dentro do threshold)
  print("1.15 Distância 4 (dentro do threshold)")
  do
    -- "abcd" vs "xbcd" = distância 1
    local m, d = fuzzy.find_closest("abcd", {"xbcd"})
    T("distância 1: retorna match", m == "xbcd")
    T("distância 1: distância correta", d == 1)
  end

  -- 1.16: Levenshtein — strings vazias
  print("1.16 Levenshtein edge cases")
  do
    local m1, d1 = fuzzy.find_closest("", {"abc"})
    T("input vazio vs 'abc': nil", m1 == nil)

    local m2, d2 = fuzzy.find_closest("abc", {"abc"})
    T("input == candidato: match exato", m2 == "abc")
  end
end

return M
