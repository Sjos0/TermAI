-- session_cmds.lua — Comandos de sessão (/new, /reset, /status, /session).
-- Reset de flush: /new e /reset zeram o flush_state para o ciclo recomeçar.

local ui            = require("ui")
local session       = require("session")
local prompt_module = require("prompt")
local tools         = require("tools")
local mf            = require("memoryflush")
local restart_mod   = require("agent.restart")

local M = {}
local REPLAY_N = 15

local function rebuild_ctx(ctx)
  ctx.msgs   = {{role = "system",
                 content = prompt_module.build(ctx.workspace, tools, session.current())}}
  ctx.tokens = 0
end

function M.do_new(ctx)
  session.new()
  rebuild_ctx(ctx)
  session.set_model(ctx.active.ref)
  -- Nova sessão começa do zero: flush_state = 0
  -- Próximo flush acontecerá ao atingir flush_tokens normalmente.
  mf.marcar_flush(0)
  io.write("\27[38;5;114m✅ Nova sessão: " .. session.current() .. "\27[0m\n\n")
  io.flush()
end

function M.do_reset(ctx)
  io.write("\27[38;5;220m⚠️  Limpar conversa atual? (s/N): \27[0m")
  io.flush()
  local confirm = io.read()
  if confirm and confirm:lower() == "s" then
    session.reset()
    rebuild_ctx(ctx)
    -- Sessão resetada: reinicia ciclo de flush do zero
    mf.marcar_flush(0)
    io.write("\27[38;5;114m✅ Conversa resetada. Sessão: "
      .. session.current() .. "\27[0m\n\n")
  else
    io.write("\27[38;5;245mCancelado.\27[0m\n\n")
  end
  io.flush()
end

function M.do_clear(ctx)
  io.write("\27[38;5;203m⚠️  Deletar permanentemente a conversa atual? (s/N): \27[0m")
  io.flush()
  local confirm = io.read()
  if confirm and confirm:lower() == "s" then
    local next_id = session.delete_current()
    io.write("\27[38;5;114m✅ Conversa deletada. Migrando para: " .. next_id .. "\27[0m\n")
    io.write("\27[38;5;243mA TUI vai reiniciar...\27[0m\n\n")
    io.flush()
    restart_mod.restart_now()
  else
    io.write("\27[38;5;245mCancelado.\27[0m\n\n")
    io.flush()
  end
end

function M.do_status(ctx)
  local st = session.status()
  if not st then
    io.write("\27[38;5;203m❌ Nenhuma sessão ativa.\27[0m\n\n")
    io.flush(); return
  end
  local tw  = require("ui.core").tw()
  local sep = string.rep("─", tw)
  io.write("\27[38;5;238m" .. sep .. "\27[0m\n")
  io.write("\27[38;5;80m  Status da Sessão\27[0m\n")
  io.write("\27[38;5;238m" .. sep .. "\27[0m\n")
  local function row(label, value)
    io.write(string.format("  \27[38;5;245m%-18s\27[0m %s\n", label, value or "—"))
  end
  row("Sessão",           st.id)
  row("Chave",            st.key)
  row("Modelo",           st.model or ctx.active.ref or "—")
  row("Criada",           st.created_at)
  row("Última atividade", st.last_activity)
  if st.last_reset then row("Último reset", st.last_reset) end
  row("Mensagens",        tostring(st.msg_count))
  local pct = st.total_tokens > 0 and ctx.active.context_window > 0
    and math.floor(st.total_tokens / ctx.active.context_window * 100) or 0
  row("Tokens", string.format("%d / %d (%d%%)",
    st.total_tokens, ctx.active.context_window, pct))
  row("Compactações", tostring(st.compaction_count))
  io.write("\27[38;5;238m" .. sep .. "\27[0m\n\n")
  io.flush()
end

-- do_session — Gerencia listagem e troca de sessões.
-- MODO INTERATIVO (/session): mostra lista numerada. O usuário digita o número.
-- MODO DIRETO (/session <id>): troca imediatamente pelo ID fornecido.
-- Em ambos os casos, após trocar a sessão ativa, a TUI é reiniciada para
-- que o startup.lua carregue o histórico da nova sessão do zero, evitando
-- mistura visual de contextos e garantindo renderização correta de tools.
function M.do_session(ctx, switch_id)
  -- MODO DIRETO: /session <id> (compatibilidade com automações)
  if switch_id and switch_id ~= "" then
    local hist = session.switch(switch_id)
    if not hist then
      io.write("\27[38;5;203m❌ Sessão não encontrada: "
        .. switch_id .. "\27[0m\n\n")
      io.flush(); return
    end
    io.write("\27[38;5;114m✅ Sessão ativa alterada. Reiniciando TUI...\27[0m\n\n")
    io.flush()
    restart_mod.restart_now()
    return
  end

  -- MODO INTERATIVO: /session (menu numerado)
  local list = session.list()
  if #list == 0 then
    io.write("\27[38;5;245m Nenhuma sessão encontrada.\27[0m\n\n")
    io.flush(); return
  end

  io.write("\n" .. "\27[1m\27[38;5;80m  Gerenciador de Sessões\27[0m\n")
  io.write("\27[38;5;245m  " .. string.rep("─", 40) .. "\27[0m\n\n")

  for idx, s in ipairs(list) do
    local num    = string.format("%2d", idx)
    local marker = s.is_active and "\27[38;5;114m ●\27[0m " or "   "
    local id_col = s.is_active
      and ("\27[1m" .. s.id .. "\27[22m")
      or  ("\27[38;5;245m" .. s.id .. "\27[0m")
    local extra = ""
    if s.model            then extra = extra .. " · " .. s.model end
    if s.compaction_count > 0 then extra = extra .. " · " .. s.compaction_count .. " comp" end
    if s.last_activity ~= ""  then extra = extra .. " · " .. s.last_activity:sub(1, 10) end
    io.write("  \27[38;5;220m" .. num .. ".\27[0m" .. marker .. id_col
      .. "\27[38;5;245m  " .. s.msg_count .. " msgs" .. extra .. "\27[0m\n")
  end

  io.write("\n\27[38;5;245m  Digite o número da sessão para trocar (0 para voltar):\27[0m ")
  io.flush()
  local choice = io.read()
  local num = tonumber(choice)

  if not num or num == 0 then
    io.write("\27[38;5;245m  Cancelado.\27[0m\n\n")
    io.flush(); return
  end

  if num < 1 or num > #list then
    io.write("\27[38;5;203m  ❌ Opção inválida.\27[0m\n\n")
    io.flush(); return
  end

  local target = list[num]
  if target.is_active then
    io.write("\27[38;5;220m  ⚠️  Essa já é a sessão ativa.\27[0m\n\n")
    io.flush(); return
  end

  local hist = session.switch(target.id)
  if not hist then
    io.write("\27[38;5;203m  ❌ Falha ao acessar a sessão: "
      .. target.id .. "\27[0m\n\n")
    io.flush(); return
  end

  io.write("\27[38;5;114m  ✅ Trocando para " .. target.id
    .. ". Reiniciando TUI...\27[0m\n\n")
  io.flush()
  restart_mod.restart_now()
end

return M
