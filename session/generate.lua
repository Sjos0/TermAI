local M = {}

local function hex_random(n)
  local f = io.open("/dev/urandom", "rb")
  if f then
    local b = f:read(n)
    f:close()
    if b and #b == n then
      local parts = {}
      for i = 1, n do
        parts[#parts + 1] = string.format("%02x", b:byte(i))
      end
      return table.concat(parts)
    end
  end
  math.randomseed(os.time() + math.floor(os.clock() * 1e6) % 1000)
  local chars = "0123456789abcdef"
  local r = ""
  for _ = 1, n * 2 do
    local i = math.random(1, 16)
    r = r .. chars:sub(i, i)
  end
  return r
end

-- Session ID: default "TUI:main:<6hex>" (invariante); aceita role/prefix opcional.
function M.id(role, prefix)
  role = role or "TUI"
  prefix = prefix or "main"
  return role .. ":" .. prefix .. ":" .. hex_random(3)
end

function M.key(role, prefix)
  role = role or "TUI"
  prefix = prefix or "main"
  return role .. ":" .. prefix
end

function M.entry_id()
  return hex_random(4)
end

function M.filename(id)
  return (id:gsub(":", "-")) .. ".jsonl"
end

return M
