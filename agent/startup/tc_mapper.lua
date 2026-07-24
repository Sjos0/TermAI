-- agent/startup/tc_mapper.lua — Mapeia tool_calls do replay: individual vs
-- agrupado (corridas de 2+ Read consecutivos, mesmo algoritmo do tool_runner).
-- Extraído de startup.lua para respeitar a Regra de Ouro (100-150 linhas).
local json = require("json")
local M = {}

function M.tc_preview_only(tc)
  local fn, p = tc["function"] or {}, ""
  local ok, a = pcall(json.decode, fn.arguments or "{}")
  if ok and type(a) == "table" then
    local v = a.command or a.path or a.query or a.expression or a.name or a.arg
    if type(v) == "string" then p = v end
  end
  return p:gsub("[\r\n]+", " ")
end

function M.tc_disp(tc)
  local fn = tc["function"] or {}
  local p  = M.tc_preview_only(tc)
  local d  = (fn.name or "?") .. " | " .. p
  return #d > 70 and d:sub(1, 70) .. "..." or d
end

-- Popula tc_id_map (lookup individual) e tc_group_map (corridas de Read 2+,
-- {gid, size, name} por tc.id). Retorna o display do último item individual
-- processado (ou nil, se o lote terminou num grupo).
function M.map_tool_calls(tcs, tc_id_map, tc_group_map)
  local last, i, n = nil, 1, #tcs
  while i <= n do
    local tc      = tcs[i]
    local fname   = (tc["function"] or {}).name
    local run_len = 1
    if fname == "Read" then
      local j = i
      while j <= n and ((tcs[j]["function"] or {}).name == "Read") do j = j + 1 end
      run_len = j - i
    end
    if run_len >= 2 then
      local gid = i
      for k = i, i + run_len - 1 do
        local kid = tcs[k].id
        if kid and kid ~= "" then
          tc_group_map[kid] = { gid = gid, size = run_len, name = M.tc_preview_only(tcs[k]) }
        end
      end
      i = i + run_len
    else
      local disp = M.tc_disp(tc)
      last = disp
      if tc.id and tc.id ~= "" then tc_id_map[tc.id] = disp end
      i = i + 1
    end
  end
  return last
end

return M
