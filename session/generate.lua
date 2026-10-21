local M = {}

-- Gera N bytes aleatórios em hex (fallback: pseudo-random)
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

-- Session ID: "TUI:main:a3f9c2" (6 hex chars)
function M.id()
  return "TUI:main:" .. hex_random(3)
end

-- Session key (fixo para TUI local — equivale ao routing key do OpenClaw)
function M.key()
  return "TUI:main"
end

-- Entry ID para entradas no transcript (8 hex chars)
function M.entry_id()
  return hex_random(4)
end

-- "TUI:main:a3f9c2" → "TUI-main-a3f9c2.jsonl"
function M.filename(id)
  return (id:gsub(":", "-")) .. ".jsonl"
end

return M
