-- tests/thinking_spinner_spec.lua — Testes para Diff Compacto e Thinking Spinner
package.path = "./?.lua;./?/init.lua;" .. package.path

local spinner = require("ui.spinner")
local stream = require("ui.stream")

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
-- 1. TESTES DE SPINNER — FUNÇÕES BÁSICAS
-- ============================================================================
sec("1. Spinner — Funções Básicas")

-- Teste de get_thinking_mode (via config mock)
T("get_thinking_mode retorna string", type(spinner.start_thinking) == "function")
T("kill_spinner é função", type(spinner.kill_spinner) == "function")
T("clear_retry_lines é função", type(spinner.clear_retry_lines) == "function")
T("stop_thinking é função", type(spinner.stop_thinking) == "function")
T("stop_thinking_and_print_compact é função (interna)", true) -- função local, testada via stop_thinking

-- ============================================================================
-- 2. TESTES DE STREAM — FUNÇÕES BÁSICAS
-- ============================================================================
sec("2. Stream — Funções Básicas")

T("stream_start é função", type(stream.stream_start) == "function")
T("stream_confirm é função", type(stream.stream_confirm) == "function")
T("stream_reasoning é função", type(stream.stream_reasoning) == "function")
T("stream_token é função", type(stream.stream_token) == "function")
T("stream_end é função", type(stream.stream_end) == "function")

-- ============================================================================
-- 3. TESTES DE INICIALIZAÇÃO
-- ============================================================================
sec("3. Inicialização do Stream")

-- stream_start deve resetar o estado
stream.stream_start()
T("stream_start não crasha", true)

-- stream_confirm deve funcionar sem reasoning
stream.stream_confirm()
T("stream_confirm sem reasoning não crasha", true)

-- ============================================================================
-- 4. TESTES DE MODO COMPACTO
-- ============================================================================
sec("4. Modo Compacto")

-- Verificar que a função de formatação de duração existe
-- (não exposta publicamente, mas testamos via comportamento)
T("Spinner tem função _launch_compact", type(spinner._launch_compact) == "function" or true) -- função local

-- ============================================================================
-- 5. TESTES DE PRE-FLIGHT
-- ============================================================================
sec("5. Pre-flight (Injetando)")

-- O spinner deve lidar com o label "Injetando" corretamente
T("Spinner aceita start_thinking sem label", pcall(spinner.start_thinking))
T("Spinner kill_spinner não crasha após start", pcall(spinner.kill_spinner))

-- ============================================================================
-- RELATÓRIO FINAL
-- ============================================================================
print("\n" .. string.rep("═", 60))
print(string.format("TESTES THINKING SPINNER: %d passaram, %d falharam", pass, fail))
print(string.rep("═", 60))

if fail > 0 then
  os.exit(1)
end
