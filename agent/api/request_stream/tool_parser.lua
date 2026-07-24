-- agent/api/request_stream/tool_parser.lua — Parsing e filtragem de tool calls do stream.
local json = require("json")
local M = {}

local _tools = (function()
  local ok, t = pcall(require, "tools")
  return ok and t or nil
end)()

function M.feed(acc, tc_delta)
  local idx = (tc_delta.index or 0) + 1
  if not acc[idx] then acc[idx] = {id = "", name = "", arguments = ""} end
  local a = acc[idx]
  if tc_delta.id and tc_delta.id ~= "" then a.id = tc_delta.id end
  local fn = tc_delta["function"]
  if fn then
    if fn.name and fn.name ~= "" then a.name = fn.name end
    if fn.arguments then a.arguments = a.arguments .. fn.arguments end
  end
end

function M.parse(acc)
  if #acc == 0 then return nil end
  local out = {}
  for _, tc in ipairs(acc) do
    local ok, a = pcall(json.decode, tc.arguments ~= "" and tc.arguments or "{}")
    out[#out + 1] = {
      id   = tc.id,
      name = tc.name,
      args = (ok and type(a) == "table") and a or {}
    }
  end
  return out
end

function M.raw(acc)
  local raw = {}
  for _, tc in ipairs(acc) do
    raw[#raw + 1] = {
      id = tc.id,
      type = "function",
      ["function"] = {name = tc.name, arguments = tc.arguments}
    }
  end
  return raw
end

function M.filter(acc)
  if not _tools then return acc end
  local reg, out = _tools.registry, {}
  for _, tc in ipairs(acc) do
    if tc.name ~= "" and reg and reg[tc.name] then
      local d = reg[tc.name]
      local ok, a = pcall(json.decode, tc.arguments ~= "" and tc.arguments or "{}")
      a = (ok and type(a) == "table") and a or {}
      local valid = true
      if d.schema and d.schema.required then
        for _, r in ipairs(d.schema.required) do
          if not a[r] or a[r] == "" then valid = false; break end
        end
      end
      if valid then out[#out + 1] = tc end
    end
  end
  return out
end

return M
