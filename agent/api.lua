-- agent/api.lua — Fachada + Constants mutáveis.
-- Interface pública inalterada: M.pensar_sync, M.pensar_stream, M.summarizar,
-- M.estimate_tokens, M.CURL_TIMEOUT, M.IDLE_TIMEOUT, M.MAX_RETRIES,
-- M.RETRY_MODE, M.RETRY_STATIC, M.RETRY_MAX
local utils      = require("agent.api.utils")
local sync       = require("agent.api.request_sync")
local stream     = require("agent.api.request_stream")
local summarizer = require("agent.api.summarizer")
local M = {}

-- Constants mutáveis — config.lua e config_cli.lua escrevem diretamente nestes campos.
M.CURL_TIMEOUT = 180
M.IDLE_TIMEOUT = 30
M.MAX_RETRIES  = 10
M.RETRY_MODE   = "exponential"
M.RETRY_STATIC = 5
M.RETRY_MAX    = 30

-- Re-exports: interface pública delega para submódulos especializados.
M.pensar_sync     = sync.pensar_sync
-- Provedor do navegador (ponte do Termavigator): não tem streaming, então usa o caminho
-- síncrono, que já lê choices[1].message com tool_calls. Os demais provedores não mudam.
local function pensar_stream_ou_ponte(ctx, txt, role)
  if ctx.active and ctx.active.api_type == "termai-navegador" then
    local content, reasoning, tool_calls = sync.pensar_sync(ctx, txt, role)
    local overflow = type(content) == "string" and content:match("^%[ERRO_OVERFLOW") ~= nil
    return content, overflow, true, reasoning, tool_calls
  end
  return stream.pensar_stream(ctx, txt, role)
end
M.pensar_stream   = pensar_stream_ou_ponte
M.summarizar      = summarizer.summarizar
M.estimate_tokens = utils.estimate_tokens

return M
