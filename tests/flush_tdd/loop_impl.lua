-- tests/flush_tdd/loop_impl.lua — implementação de referência do loop do flush (TDD, usada por tests/flush_tdd_loop_spec.lua).
local M = {}

-- Simula o flush loop work: detect_gates + render_checklist + decisão
-- turnos: tabela de turnos simulados, cada um com tool_calls e resp
-- max_iter: limite máximo de iterações
-- Retorna { done, estado_final, turnos_executados }
function M.simular(turnos, max_iter)
  max_iter = max_iter or 10

  -- Estado inicial (como em T1)
  local fs = { exec = false, read = false, edit = false, done = false }
  function fs.reset()
    fs.exec = false; fs.read = false; fs.edit = false; fs.done = false
  end

  -- detect_gates (mesma lógica de produção / T2 alinhado)
  local function detect_gates(tool_calls, resp, flush_state, tool_results)
    tool_results = tool_results or {}
    if tool_calls and #tool_calls > 0 then
      for i, tc in ipairs(tool_calls) do
        local func = tc["function"] or tc
        local name = func.name or tc.name
        local args = func.arguments or tc.arguments or ""
        local args_str = type(args) == "string" and args or (type(args) == "table" and (args.file or args.path or "") or "")
        if not flush_state.exec and name == "Exec" and (args_str:match("date") or args_str:match("%%Y")) then
          flush_state.exec = true
        end
        if not flush_state.read and name == "Read" and (args_str:match("memory/") or args_str:match("%.md")) then
          flush_state.read = true
        end
        if not flush_state.edit and (name == "Edit" or name == "Write") and (args_str:match("memory/") or args_str:match("%.md")) then
          local result = tool_results[i]
          if result == nil or result == true then flush_state.edit = true end
        end
      end
    end
    if not flush_state.done and resp and resp:match("%[FLUSH_DONE%]") then
      flush_state.done = true
    end
  end

  -- render_checklist (como T3)
  local function render_checklist(fs)
    local x, o = "[x]", "[ ]"
    return string.format("<FLUSH_STATUS>\n  %s exec  %s read  %s edit  %s done\n</FLUSH_STATUS>",
      fs.exec and x or o, fs.read and x or o, fs.edit and x or o, fs.done and x or o)
  end

  local iter = 0
  local gen_turnos = turnos or {}

  while iter < max_iter do
    iter = iter + 1

    -- Pega dados do turno simulado
    local turno = gen_turnos[iter] or { tool_calls = {}, resp = "", tool_results = {} }

    -- Renderiza checklist (o modelo "vê" isso)
    local checklist = render_checklist(fs)

    -- Simula API + tool_runner (dados mock)
    local tool_calls = turno.tool_calls or {}
    local resp = turno.resp or ""
    local tool_results = turno.tool_results or {}

    -- Detecta gates
    detect_gates(tool_calls, resp, fs, tool_results)

    -- Se done, retorna sucesso
    if fs.done then
      return { done = true, estado = fs, iteracoes = iter, checklist = checklist }
    end
  end

  -- MAX_ITER estourado sem done
  return { done = false, estado = fs, iteracoes = iter, checklist = render_checklist(fs) }
end

-- ==========================================
-- TESTES
-- ==========================================
return M
