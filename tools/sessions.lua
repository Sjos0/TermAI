-- tools/sessions.lua — Ferramentas de gestão de sessões.
-- v2: schemas JSON para native tool calling + arg backward compat.
local M = {}

function M.register(tools)
  tools.register("sessoes_listar",
    "Lista todas as sessões de conversa salvas com metadados. Sem argumentos.",
    function(arg)
      local session = require("session")
      local list = session.list()
      if #list == 0 then return "Nenhuma sessão encontrada." end
      local result = "Sessões:\n"
      for _, s in ipairs(list) do
        local active_tag = s.is_active and " [ATIVA]" or ""
        result = result .. "- " .. s.id .. active_tag
          .. " | " .. s.msg_count .. " msgs"
          .. " | " .. s.tokens .. " tokens"
        if s.compaction_count and s.compaction_count > 0 then
          result = result .. " | " .. s.compaction_count .. " comp"
        end
        if s.model then result = result .. " | modelo: " .. s.model end
        result = result .. "\n"
      end
      return result
    end,
    {type = "object", properties = {}}
  )

  tools.register("sessoes_historico",
    "Lê o histórico de uma sessão específica. Arg: session_id (opcional, padrão=sessão ativa).",
    function(arg)
      local session_id = type(arg) == "table"
        and (arg.session_id or nil)
        or (arg ~= "" and arg or nil)
      local session = require("session")
      local store   = require("session.store")
      local target  = session_id or session.current()
      local entries = store.read_entries(target)
      if #entries == 0 then return "Sessão não encontrada ou vazia: " .. target end
      local result = "Histórico da sessão " .. target .. ":\n\n"
      local count  = 0
      for _, e in ipairs(entries) do
        if e.type == "message" or (not e.type and e.role) then
          local role    = e.role or "?"
          local content = e.content or ""
          if #content > 500 then content = content:sub(1, 497) .. "..." end
          result = result .. "[" .. role .. "] " .. content .. "\n\n"
          count  = count + 1
        elseif e.type == "compaction" then
          result = result .. "[COMPACTAÇÃO] " .. (e.summary or "(sem resumo)") .. "\n\n"
        end
      end
      return result .. "Total: " .. count .. " mensagens"
    end,
    {
      type = "object",
      properties = {
        session_id = {type = "string", description = "ID da sessão (opcional, padrão=sessão ativa)"}
      }
    }
  )

  tools.register("sessao_status",
    "Mostra status detalhado da sessão ativa.",
    function(arg)
      local session = require("session")
      local st = session.status()
      if not st then return "Nenhuma sessão ativa." end
      local lines = {
        "Sessão: "           .. st.id,
        "Chave: "            .. st.key,
        "Modelo: "           .. (st.model or "—"),
        "Criada: "           .. st.created_at,
        "Última atividade: " .. st.last_activity,
        "Mensagens: "        .. st.msg_count,
        "Tokens: "           .. st.total_tokens,
        "Compactações: "     .. st.compaction_count,
      }
      if st.last_reset then lines[#lines+1] = "Último reset: " .. st.last_reset end
      return table.concat(lines, "\n")
    end,
    {type = "object", properties = {}}
  )
end

return M
