-- agent/loop/tool_runner/executor.lua — Orquestração de execuções individuais e em lote.
local ui        = require("ui")
local tools_mod = require("tools")
local json      = require("json")
local display   = require("agent.loop.tool_runner.display")
local tracker   = require("agent.loop.tool_runner.tracker")
local suffix    = require("agent.loop.tool_runner.suffix")

local M = {}

local function get_wall_time()
  local f = io.open("/proc/uptime", "r")
  if not f then return os.time() end
  local val = f:read("*n")
  f:close()
  return val or os.time()
end

local function is_read_call(tc)
  return tc.name == "Read" and tools_mod.registry[tc.name] ~= nil
end

local function executar_individual(ctx, tc)
  local result
  if not tc.name or tc.name == "" or not tools_mod.registry[tc.name] then
    local bad  = tostring(tc.name or "")
    local disp = "(inválida: '" .. bad .. "')"
    ui.tool_start(disp)
    local avail = {}
    for n in pairs(tools_mod.registry) do avail[#avail + 1] = n end
    table.sort(avail)
    result = "❌ Ferramenta '" .. bad .. "' não existe. Disponíveis: "
           .. table.concat(avail, ", ")
    ui.tool_end(disp, result, false)
  else
    local json_ok, args_str = pcall(json.encode, tc.args or {})
    local tc_sig = tc.name .. ":" .. (json_ok and args_str or "")

    if ctx.last_tool_sig == tc_sig and (tc.name == "Write" or tc.name == "Edit") then
      local display_str = display.tc_display(tc) .. " [REDUNDANTE]"
      ui.tool_start(display_str)
      result = "⚠️ [Harness] Bloqueio de redundância: Esta mesma chamada de ferramenta (" .. tc.name
             .. ") com os mesmos argumentos exatos já foi executada na iteração anterior. "
             .. "Se você precisa verificar o resultado ou realizar outro ajuste, prossiga de outra forma."
      ui.tool_end(display_str, result, false)
    else
      ctx.last_tool_sig = tc_sig
      local display_str = display.tc_display(tc)
      ui.tool_start(display_str)

      local start_t = get_wall_time()
      result = tools_mod.call_structured(tc.name, tc.args)
      local elapsed_ms = math.max(0, math.floor((get_wall_time() - start_t) * 1000))

      local bp = require("agent.hooks.bash_patterns")
      local perms = require("agent.hooks.permissions")
      local last_app = bp.last_approval_type or perms.last_approval_type or "AUTO_APPROVED"

      bp.last_approval_type, perms.last_approval_type = nil, nil

      if last_app == "CANCELLED" then
        ctx.tool_cancelled = true
        result = "❌ Action cancelled by user."
      end

      local success = not result:match("^❌")
      ui.tool_end(display_str, result, success)

      if not ctx.tool_cancelled then
        tracker.track_file(ctx, tc.name, tc.args, success)
      end

      ctx.msgs[#ctx.msgs + 1] = {
        role         = "tool",
        tool_call_id = tc.id,
        content      = result .. suffix.build_system_suffix(ctx, elapsed_ms, last_app),
      }
      return
    end
  end

  ctx.msgs[#ctx.msgs + 1] = {
    role         = "tool",
    tool_call_id = tc.id,
    content      = result .. suffix.build_system_suffix(ctx, nil, nil),
  }
end

local function executar_grupo_read(ctx, tcs)
  ui.tool_group_read_start(#tcs)
  local names, oks = {}, {}
  for _, tc in ipairs(tcs) do
    local start_t = get_wall_time()
    local result = tools_mod.call_structured(tc.name, tc.args)
    local elapsed_ms = math.max(0, math.floor((get_wall_time() - start_t) * 1000))

    local bp = require("agent.hooks.bash_patterns")
    local perms = require("agent.hooks.permissions")
    local last_app = bp.last_approval_type or perms.last_approval_type or "AUTO_APPROVED"

    bp.last_approval_type, perms.last_approval_type = nil, nil

    if last_app == "CANCELLED" then
      ctx.tool_cancelled = true
      result = "❌ Action cancelled by user."
    end

    local ok = not result:match("^❌")
    names[#names + 1], oks[#oks + 1] = display.tc_preview(tc), ok

    if not ctx.tool_cancelled then
      tracker.track_file(ctx, tc.name, tc.args, ok)
    end

    ctx.msgs[#ctx.msgs + 1] = {
      role         = "tool",
      tool_call_id = tc.id,
      content      = result .. suffix.build_system_suffix(ctx, elapsed_ms, last_app),
    }

    if ctx.tool_cancelled then break end
  end
  ui.tool_group_read_end(names, oks)
end

function M.run_batch(ctx, tool_calls)
  local i, n = 1, #tool_calls
  while i <= n do
    local tc      = tool_calls[i]
    local run_len = 1
    if is_read_call(tc) then
      local j = i
      while j <= n and is_read_call(tool_calls[j]) do j = j + 1 end
      run_len = j - i
    end
    if run_len >= 2 then
      local group = {}
      for k = i, i + run_len - 1 do group[#group + 1] = tool_calls[k] end
      executar_grupo_read(ctx, group)
      if ctx.tool_cancelled then break end
      i = i + run_len
    else
      executar_individual(ctx, tc)
      if ctx.tool_cancelled then break end
      i = i + 1
    end
  end
end

return M
