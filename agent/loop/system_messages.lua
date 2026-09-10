-- agent/loop/system_messages.lua — Injeções invisíveis de System Messages e memória.
-- Estilo Claude Code: boot/login, restart e cancelamento prévio.
-- Também aplica injeção automática de memória relevante no turno do usuário.
local ui = require("ui")

local M = {}

-- Sinalizador de boot (RAM-only): determina login vs restart no primeiro turno de rede.
-- Estado de módulo — sobrevive entre chamadas de M.rodar na mesma sessão Lua.
local is_first_turn = true

local _mem = (function()
  local ok, m = pcall(require, "tools.memory")
  return ok and m or nil
end)()

--- Prepara o texto do turno do usuário com system messages e memória.
-- Só aplica injeções quando cur_role == "user".
-- @param ctx table Contexto do agente (pode mutar prev_command_cancelled)
-- @param cur_text string Texto atual do prompt
-- @param cur_role string Role atual
-- @return string cur_text atualizado
-- @return boolean spinner_started (true se iniciou spinner de memória)
function M.prepare_user_turn(ctx, cur_text, cur_role)
  local spinner_started = false

  if cur_role ~= "user" then
    return cur_text, spinner_started
  end

  -- Proteção contra loops redundantes: reinicia assinatura ao novo prompt do usuário
  ctx.last_tool_sig = nil

  local system_injections = {}

  -- 1. Detecção de Boot: primeira chamada de rede da sessão Lua atual
  if is_first_turn then
    is_first_turn = false
    if #ctx.msgs <= 1 then
      system_injections[#system_injections + 1] =
        "[SYSTEM MESSAGE: User has joined the session. Ready for instructions.]"
    else
      system_injections[#system_injections + 1] =
        "[SYSTEM MESSAGE: System has restarted. Session state and working directory are preserved. Ready to continue.]"
    end
  end

  -- 2. Detecção de Cancelamento prévio no Prompt
  if ctx.prev_command_cancelled then
    ctx.prev_command_cancelled = nil
    system_injections[#system_injections + 1] =
      "[SYSTEM MESSAGE: The previous bash command/action was CANCELLED by the user. Modify your approach or ask for clarification.]"
  end

  if #system_injections > 0 then
    cur_text = table.concat(system_injections, "\n") .. "\n\n" .. (cur_text or "")
  end

  -- 3. Injeção automática de memória relevante
  if _mem and cur_text and #cur_text > 2 then
    ui.start_thinking("Injetando")
    spinner_started = true
    local ok, mem = pcall(_mem.search, cur_text)
    if ok and mem
       and not mem:match("^❌")
       and not mem:match("^📭")
       and not mem:match("^🔍 Nenhuma") then
      cur_text = "[MEMÓRIA RELEVANTE — injetada automaticamente]\n"
               .. mem .. "\n---\n" .. cur_text
    end
    ui.update_label()
  end

  return cur_text, spinner_started
end

return M
