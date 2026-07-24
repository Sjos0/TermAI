-- payload.lua — Construção do payload JSON para a API.
-- v3: native tool calling via parâmetro tools; suporte a txt=nil (continue após tools).
-- v3: ctx.no_tools trava o schema de ferramentas fora do payload (REQ-8).
local json  = require("json")
local utils = require("agent.api.utils")
local M     = {}

local function build_payload(ctx, txt, role, stream)
  if txt ~= nil then
    table.insert(ctx.msgs, {role = role or "user", content = txt})
  end

  local prompt_est = math.ceil(utils.estimate_tokens(ctx.msgs) * 1.1)
  local cw         = ctx.active.context_window or 8192
  local available  = cw - prompt_est - 1000
  if available <= 0 then return nil end

  local safe_max = math.min(ctx.active.max_tokens, available)

  local payload = {
    model       = ctx.active.model_id,
    messages    = ctx.msgs,
    temperature = ctx.cfg and (ctx.cfg.agents.defaults.temperature or 0.5) or 0.5,
    max_tokens  = safe_max,
  }

  -- REQ-8 (compactação): ctx.no_tools remove o schema do payload — não é
  -- só pedir no prompt pro modelo não chamar tool, é não oferecer a
  -- opção. Chat normal nunca seta isso (ctx.no_tools fica nil), então
  -- esse comportamento não muda em nada.
  local ok_t, tools_mod = pcall(require, "tools")
  if not ctx.no_tools and ok_t and tools_mod.get_schema then
    local schema = tools_mod.get_schema()
    if schema then
      payload.tools       = schema
      payload.tool_choice = "auto"
    end
  end

  if stream then
    payload.stream = true
    payload.stream_options = { include_usage = true }
  end

  if ctx.active.reasoning then
    local style = ctx.active.reasoning_style or "openrouter"
    if style == "openrouter" then
      payload.include_reasoning = true
      local req_cfg = ctx.cfg and ctx.cfg.agents and ctx.cfg.agents.defaults
                      and ctx.cfg.agents.defaults.request
      local effort = (ctx.active.default_effort)
                   or (req_cfg and req_cfg.reasoning_effort)
                   or "medium"
      local valid = {xhigh=true,high=true,medium=true,low=true,minimal=true,none=true}
      if not valid[effort] then effort = "medium" end
      payload.reasoning = { effort = effort }
    elseif style == "chat_template_kwargs" then
      payload.chat_template_kwargs = { thinking = true }
    elseif style == "reasoning_effort" then
      payload.reasoning_effort = ctx.cfg and ctx.cfg.agents.defaults.thinkingEffort or "high"
    end
  end

  local raw = json.encode(payload)
  raw = raw:gsub('"properties"%s*:%s*%[%]', '"properties":{}')
  return raw
end

M.build_payload = build_payload
return M
