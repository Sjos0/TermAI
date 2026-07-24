-- message_classifier.lua — Classifica mensagens do histórico para o replay.
-- Retorna (kind, a, b, d) com aridade variável conforme o tipo:
--   "skip"                -> (kind, "")
--   "user"/"assistant"    -> (kind, text)
--   "tool_call"           -> (kind, display)
--   "tool_call_with_text" -> (kind, display, leftover)
--   "tool_result"         -> (kind, name, status, output)
local xclean = require("agent.startup.xml_cleaner")
local M = {}

-- Classifica e limpa cada mensagem antes de exibir no replay.
-- Remove timestamp (era para o modelo), detecta tool_call e tool_result.
local function classify(role, content)
  if not content or content == "" then return "skip", "" end

  local text = content:gsub("^%[%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d%]%s*", "")

  if role == "user" and text:match("^<tool_result") then
    local name   = text:match('name="([^"]+)"') or "ferramenta"
    local status = text:match('status="([^"]+)"') or "ok"
    local output = text:match("<tool_result[^>]*>\n?(.-)\n?</tool_result>") or ""
    return "tool_result", name, status, output
  end

  if role == "assistant" and text:match("<tool>") then
    local flat_text = text:gsub("\n", " ")
    local name = flat_text:match("<name>%s*(.-)%s*</name>") or "ferramenta"
    local arg  = (flat_text:match("<arg>%s*(.-)%s*</arg>") or ""):match("^%s*(.-)%s*$")
    local display = name .. " | " .. arg
    if #display > 70 then display = display:sub(1, 67) .. "..." end
    local leftover = xclean.strip_tool_xml(text)
    if leftover ~= "" then
      return "tool_call_with_text", display, leftover
    end
    return "tool_call", display
  end

  if text:match("^%s*$") then return "skip", "" end
  return role, text
end

M.classify = classify
return M
