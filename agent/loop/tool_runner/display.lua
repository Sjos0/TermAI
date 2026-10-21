-- agent/loop/tool_runner/display.lua — Formatação visual e assinaturas de tool calls.
local M = {}

local LABELS = { sessions_spawn = "Subagente" }

function M.tc_preview(tc)
  local a       = tc.args
  local preview = ""
  if type(a) == "table" then
    if tc.name == "Grep" then
      preview = string.format('"%s" in %s', a.pattern or "", a.path or ".")
    elseif tc.name == "Read" and a.start_line then
      preview = string.format('%s:%s-%s', a.path or "", a.start_line, a.end_line or a.start_line)
    else
      local p = a.command or a.path or a.query or a.expression or a.name or a.arg or a.task
      if p and type(p) == "string" then
        preview = p
      else
        for _, v in pairs(a) do
          if type(v) == "string" and v ~= "" then preview = v; break end
        end
      end
    end
  end
  return preview:gsub("[\r\n]+", " ")
end

function M.tc_display(tc)
  local d = (LABELS[tc.name] or tc.name) .. " | " .. M.tc_preview(tc)
  return #d > 70 and d:sub(1, 70) .. "..." or d
end

return M
