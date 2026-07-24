-- timestamp.lua — Captura e formatação de timestamps do sistema.
-- Dependências externas: nenhuma (io.popen, os.date).
local M = {}

-- Captura timestamp real do sistema (bash) para evitar drift do Android.
local function capture_timestamp()
  local h = io.popen("date '+%Y-%m-%d %H:%M:%S' 2>/dev/null")
  if not h then return os.date("%Y-%m-%d %H:%M:%S") end
  local ts = h:read("*l") or ""
  h:close()
  return (ts ~= "") and ts or os.date("%Y-%m-%d %H:%M:%S")
end

-- Extrai HH:MM do timestamp "YYYY-MM-DD HH:MM:SS" para o footer.
local function ts_to_hhmm(ts)
  return ts:match("%d%d%d%d%-%d%d%-%d%d (%d%d:%d%d)") or ts:sub(1, 5)
end

M.capture = capture_timestamp
M.to_hhmm = ts_to_hhmm
return M
