-- :format_context do flush: contexto vazio, labels, strip de tags, truncamento e conteúdo vazio.
local harness = require("tests.helpers.harness")
local T, sec = harness.T_so_falhas, harness.sec

local M = {}

function M.run()
  -- ─────────────────────────────────────────────────────────────
  -- format_context.format_context
  -- ─────────────────────────────────────────────────────────────
  sec("format_context.format_context")

  local fc = require("agent.flush.format_context")

  T("msgs vazia → mensagem padrão",
    fc.format_context({}) == "[Nenhuma mensagem nova desde o último Flush]")

  local only_system = fc.format_context({
    { role = "system", content = "ignorar" },
  })
  T("só system → contexto sem mensagens relevantes",
    only_system == "[Contexto sem mensagens relevantes]")

  local user_asst = fc.format_context({
    { role = "user", content = "olá mundo" },
    { role = "assistant", content = "resposta" },
  })
  T("user+assistant → labels USUÁRIO e AGENTE",
    user_asst:find("%[USUÁRIO%]") ~= nil
    and user_asst:find("%[AGENTE%]") ~= nil
    and user_asst:find("olá mundo") ~= nil
    and user_asst:find("resposta") ~= nil)

  T("separador ─ entre mensagens",
    user_asst:find(string.rep("─", 30)) ~= nil)

  local with_tools = fc.format_context({
    {
      role = "assistant",
      content = "antes <tool>call</tool> meio <tool_result id=\"1\">ok</tool_result> depois",
    },
  })
  T("strip <tool> e <tool_result>",
    with_tools:find("<tool>") == nil
    and with_tools:find("<tool_result") == nil
    and with_tools:find("antes") ~= nil
    and with_tools:find("depois") ~= nil)

  local long = string.rep("x", 1600)
  local truncated = fc.format_context({
    { role = "user", content = long },
  })
  T("trunca conteúdo >1500 chars",
    truncated:find("… %[truncado%]") ~= nil
    and #truncated < 1600 + 50)

  local blank = fc.format_context({
    { role = "user", content = "   \n\t  " },
    { role = "assistant", content = "ok" },
  })
  T("conteúdo só whitespace é ignorado",
    blank:find("%[USUÁRIO%]") == nil
    and blank:find("%[AGENTE%]") ~= nil
    and blank:find("ok") ~= nil)

  local nil_content = fc.format_context({
    { role = "user", content = nil },
  })
  T("content nil não explode (vira string vazia / ignorado)",
    type(nil_content) == "string")
end

return M
