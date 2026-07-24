-- simple.lua — Comandos simples de navegação e sessão: /new, /reset,
-- /session (cleanup/switch/status), /status, /help, /restart.
-- Cada comando, se corresponder, sinaliza action="continue" (equivalente
-- ao `goto continue` do loop principal). Se nenhum corresponder, retorna {}.
local restart_mod = require("agent.restart")
local session      = require("session")
local sess_cmds     = require("agent.session_cmds")

local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
local BASE = HOME .. "/TermAI"

local M = {}

local function route(input, ctx, flush_msgs_start)
  if input == "/new" then
    sess_cmds.do_new(ctx)
    return { action = "continue", flush_msgs_start = 2 }
  end
  if input == "/reset" then
    sess_cmds.do_reset(ctx)
    return { action = "continue", flush_msgs_start = 2 }
  end
  if input == "/clear" then
    sess_cmds.do_clear(ctx)
    return { action = "continue", flush_msgs_start = 2 }
  end

  if input:match("^/session cleanup") then
    local dry = input:match("--dry%-run") ~= nil
    local removed, kept = session.cleanup(dry)
    io.write(dry
      and "\27[38;5;220m⚠️  Dry-run — nada foi removido.\27[0m\n"
      or  "\27[38;5;114m✅ Limpeza concluída.\27[0m\n")
    io.write("\27[38;5;245m  Removidas: " .. #removed
      .. "  Mantidas: " .. #kept .. "\27[0m\n")
    if dry and #removed > 0 then
      for _, s in ipairs(removed) do
        io.write("    \27[38;5;245m- " .. (s.id or "?") .. "\27[0m\n")
      end
    end
    io.write("\n"); io.flush()
    return { action = "continue" }
  end

  do
    local sw = input:match("^/session%s+(.+)$")
    if input == "/session" or sw then
      sess_cmds.do_session(ctx, sw)
      return { action = "continue" }
    end
  end

  if input == "/status" then
    sess_cmds.do_status(ctx)
    return { action = "continue" }
  end

  if input == "/help" then
    dofile(BASE .. "/commands/help.lua")
    return { action = "continue" }
  end

  if input == "/restart" then
    restart_mod.request()
    return { action = "continue" }
  end

  return {}
end

M.route = route
return M
