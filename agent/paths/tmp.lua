-- agent/paths/tmp.lua — diretório temporário único (#207).
local M = {}
local _cached

function M.dir()
  if _cached then return _cached end
  local home = os.getenv("HOME") or ""
  local candidates = {
    os.getenv("TMPDIR"),
    "/data/data/com.termux/files/usr/tmp",
    home ~= "" and (home .. "/.TermAI/tmp") or nil,
    "/tmp",
  }
  for _, d in ipairs(candidates) do
    if d and d ~= "" then
      local probe = d .. "/.ta_wprobe_" .. tostring(os.time())
      local f = io.open(probe, "w")
      if f then
        f:close(); os.remove(probe)
        _cached = d
        return d
      end
    end
  end
  _cached = os.getenv("TMPDIR") or "/tmp"
  return _cached
end

return M
