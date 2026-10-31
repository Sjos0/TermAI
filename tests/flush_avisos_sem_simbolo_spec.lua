-- tests/flush_avisos_sem_simbolo_spec.lua
-- Issue #326 — os avisos do Memory Flush passam a ser em palavras: [WARN] e [OK],
-- sem símbolo. Executa o código REAL (agent/flush/loop.lua e
-- agent/main_loop/flush_handler.lua) com apenas agent.api, ui, tool_runner e as
-- dependências do handler como dublês.

package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local falhas = 0
local function check(cond, msg)
  if cond then
    print("ok   - " .. msg)
  else
    print("FAIL - " .. msg)
    falhas = falhas + 1
  end
end

-- Coletor de io.write: observa a saída real, sem alterar a lógica de produção.
local _write = io.write
local buf = {}
local function capturar(fn)
  buf = {}
  io.write = function(...)
    local t = table.pack(...)
    local s = {}
    for i = 1, t.n do s[i] = tostring(t[i]) end
    buf[#buf + 1] = table.concat(s)
  end
  local ok, err = pcall(fn)
  io.write = _write
  return table.concat(buf), ok, err
end

local modo_api, flush_done = "aborto", true

package.preload["agent.api"] = function()
  return {
    pensar_stream = function()
      if modo_api == "aborto" then
        return "[ERRO] Falha após 2 tentativas — Sem resposta do servidor",
               false, nil, "", nil
      end
      return "apenas raciocínio, sem tool_calls e sem o sinal de conclusão", false, true, "", nil
    end,
  }
end

package.preload["agent.loop.tool_runner"] = function()
  return { run_batch = function()
    error("tool_runner não deveria rodar neste teste")
  end }
end

package.preload["ui"] = function()
  return {
    update_label   = function() end,
    start_thinking = function() end,
    stop_thinking  = function() return 0 end,
  }
end

package.preload["memoryflush"] = function()
  return {
    deve_flush       = function() return true end,
    get_flush_prompt = function() return "PROTOCOLO DE TESTE" end,
    marcar_flush     = function() end,
  }
end
package.preload["agent.api.utils"] = function()
  return { ensure_tokens = function() end }
end
package.preload["agent.banners"]           = function() return { flush = function() end } end
package.preload["session"]                 = function() return { save_flush_index = function() end } end
package.preload["agent.compaction"]        = function() return { get_mf_config = function() return {} end } end
package.preload["agent.flush"]             = function() return { run = function() return flush_done end } end
package.preload["agent.main_loop.persistence"] = function() return { flush_ativo = function() return true end } end
package.preload["agent.hooks.engine"]      = function() return { run = function() end } end

local flush_loop = require("agent.flush.loop")
local handler    = require("agent.main_loop.flush_handler")

local function novo_ctx()
  return {
    cfg = {}, tokens = 0, MAX_ITER = 10,
    msgs = {
      { role = "system", content = "sys" },
      { role = "user",   content = "ctx" },
    },
    flush_state = { exec = false, read = false, edit = false, done = false,
                    reset = function() end },
  }
end

-- ── 1) Aborto por erro de API ───────────────────────────────────────────────
modo_api = "aborto"
local done
local saida1 = capturar(function() done = flush_loop.run_loop(novo_ctx(), "prompt") end)
check(done == false, "aborto de API devolve done=false")
check(saida1:find("[WARN] Memory Flush aborted (API):", 1, true) ~= nil,
  "aviso de aborto em palavras: [WARN] Memory Flush aborted (API):")
check(saida1:find("Memory Flush abortado", 1, true) == nil,
  "texto antigo 'Memory Flush abortado' removido")
check(saida1:find("⚠", 1, true) == nil,
  "sem símbolo ⚠ no aviso de aborto (comparado com o novo)")

-- ── 2) MAX_ITER esgotado ────────────────────────────────────────────────────
modo_api = "sem_tool"
local saida2 = capturar(function() done = flush_loop.run_loop(novo_ctx(), "prompt") end)
check(done == false, "MAX_ITER devolve done=false")
check(saida2:find("[WARN] Memory Flush MAX_ITER", 1, true) ~= nil,
  "aviso de MAX_ITER em palavras")
check(saida2:find("⚠", 1, true) == nil, "sem símbolo ⚠ no aviso de MAX_ITER")

-- ── 3) Conclusão (flush_handler) ────────────────────────────────────────────
flush_done = true
local ctx_h = { tokens = 9999, msgs = { { role = "user", content = "oi" } } }
local saida3 = capturar(function() handler.handle(ctx_h, "sair", 1) end)
check(saida3:find("[OK] Memory Flush completed", 1, true) ~= nil,
  "conclusão: [OK] Memory Flush completed")
check(saida3:find("✅", 1, true) == nil, "sem símbolo ✅ na conclusão")

-- ── 4) Flush incompleto (flush_handler) ─────────────────────────────────────
flush_done = false
local saida4 = capturar(function() handler.handle(ctx_h, "sair", 1) end)
check(saida4:find("[WARN] Flush incompleto", 1, true) ~= nil,
  "aviso de flush incompleto em palavras")
check(saida4:find("⚠", 1, true) == nil, "sem símbolo ⚠ no flush incompleto")

if falhas > 0 then
  print(("\nFAIL  flush_avisos_sem_simbolo_spec: %d verificação(ões) falharam"):format(falhas))
  os.exit(1)
end
print("\nPASS  flush_avisos_sem_simbolo_spec")
