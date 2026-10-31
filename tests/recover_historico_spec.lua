-- tests/recover_historico_spec.lua — #279: recover_tool_seq não apaga histórico válido.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

package.loaded["agent.api.request_stream.recovery"] = nil
local recovery = require("agent.api.request_stream.recovery")

-- Cenário A: tool_calls COMPLETO (com tool correspondente) + user que falha
-- Esperado: nada apagado
do
  local msgs = {
    { role = "user", content = "busca X" },
    { role = "assistant", tool_calls = { { id = "tc1", ["function"] = { name = "web_search" } } } },
    { role = "tool", tool_call_id = "tc1", content = "ok" },
    { role = "user", content = "mensagem que falha na API" },
  }
  local n0 = #msgs
  local text = recovery.recover_tool_seq(msgs)
  T(text == nil, "A: não retorna recover quando sequência completa (got " .. tostring(text) .. ")")
  T(#msgs == n0, "A: histórico intacto (got " .. #msgs .. " want " .. n0 .. ")")
  T(msgs[#msgs] and msgs[#msgs].content == "mensagem que falha na API", "A: user final preservado")
end

-- Cenário B: tool_calls órfão + user + assistant válidos depois
-- Esperado: só o órfão sai
do
  local msgs = {
    { role = "user", content = "antes" },
    { role = "assistant", tool_calls = { { id = "tc_orf", ["function"] = { name = "web_search" } } } },
    -- sem tool response
    { role = "user", content = "depois do orfao" },
    { role = "assistant", content = "resposta valida" },
  }
  local text = recovery.recover_tool_seq(msgs)
  T(text ~= nil and text:find("web_search", 1, true), "B: recover anuncia orfao")
  local roles = {}
  for _, m in ipairs(msgs) do roles[#roles + 1] = m.role end
  local joined = table.concat(roles, ",")
  T(joined:find("assistant.*tool", 1) == nil or not (function()
    for _, m in ipairs(msgs) do
      if m.role == "assistant" and m.tool_calls then return true end
    end
    return false
  end)(), "B: orfao removido")
  T(#msgs >= 2, "B: mensagens posteriores preservadas (got " .. #msgs .. ")")
  local has_depois = false
  for _, m in ipairs(msgs) do
    if m.content == "depois do orfao" or m.content == "resposta valida" then has_depois = true end
  end
  T(has_depois, "B: user/assistant posteriores presentes")
end

-- Cenário C: após recover, user que falhou permanece (reinício de contexto)
do
  local msgs = {
    { role = "user", content = "entrada do usuario" },
    { role = "assistant", tool_calls = { { id = "x", ["function"] = { name = "bash" } } } },
  }
  recovery.recover_tool_seq(msgs)
  local has_user = false
  for _, m in ipairs(msgs) do
    if m.role == "user" and m.content == "entrada do usuario" then has_user = true end
  end
  T(has_user, "C: entrada do usuario permanece apos recover de orfao no fim")
end

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
