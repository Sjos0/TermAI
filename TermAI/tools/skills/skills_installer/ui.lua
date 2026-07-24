local M = {}

local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
local BASE = HOME .. "/TermAI"

-- Cores ANSI
local ESC = "\27["
local RESET = ESC .. "0m"
local BOLD = ESC .. "1m"
local DIM = ESC .. "2m"
local GREEN = ESC .. "38;5;114m"
local RED = ESC .. "38;5;196m"
local CYAN = ESC .. "38;5;80m"
local GRAY = ESC .. "38;5;245m"
local WHITE = ESC .. "38;5;255m"

function M.banner()
  local f = io.open(BASE .. "/banner.txt", "r")
  if not f then return end
  local lines = {}
  local max_w = 0
  for line in f:lines() do
    lines[#lines + 1] = line
    if #line > max_w then max_w = #line end
  end
  f:close()

  local term_w = 80
  local box_w = max_w + 4
  local pad = math.max(0, math.floor((term_w - box_w) / 2))
  local margin = string.rep(" ", pad)

  io.write(margin .. GRAY .. WHITE .. "╭" .. string.rep("─", box_w - 2) .. "╮\n" .. RESET)
  for i, line in ipairs(lines) do
    local ratio = (#lines > 1) and ((i - 1) / (#lines - 1)) or 0
    local r = math.floor(60  + (0   - 60)  * ratio)
    local g = math.floor(180 + (40  - 180) * ratio)
    local b = math.floor(255 + (150 - 255) * ratio)
    local color = string.format(ESC .. "38;2;%d;%d;%dm", r, g, b)
    local padded = line .. string.rep(" ", max_w - #line)
    io.write(margin .. GRAY .. WHITE .. "│ " .. RESET
          .. color .. BOLD .. padded .. RESET
          .. GRAY .. WHITE .. " │\n" .. RESET)
  end
  io.write(margin .. GRAY .. WHITE .. "╰" .. string.rep("─", box_w - 2) .. "╯\n" .. RESET)
end

function M.processing(text)
  io.write(CYAN .. "⏳ " .. text .. "..." .. RESET .. "\n")
  io.flush()
end

function M.result_ok(skill, path)
  io.write(GREEN .. "  ✅ " .. skill .. RESET .. GRAY .. " → " .. path .. RESET .. "\n")
end

function M.result_fail(skill, error_msg)
  io.write(RED .. "  ❌ " .. skill .. RESET .. GRAY .. " → " .. (error_msg or "erro desconhecido") .. RESET .. "\n")
end

function M.result_skip(skill, reason)
  io.write(GRAY .. "  ⏭ " .. skill .. " — " .. reason .. RESET .. "\n")
end

function M.summary(results)
  local ok = 0
  local fail = 0
  local skip = 0
  for _, r in ipairs(results) do
    if r.status == "ok" then ok = ok + 1
    elseif r.status == "skip" then skip = skip + 1
    else fail = fail + 1 end
  end
  io.write("\n" .. GRAY .. "  ── Resumo ──" .. RESET .. "\n")
  if ok > 0 then io.write(GREEN .. "  ✅ " .. ok .. " instalada(s)" .. RESET .. "\n") end
  if fail > 0 then io.write(RED .. "  ❌ " .. fail .. " falhou" .. RESET .. "\n") end
  if skip > 0 then io.write(GRAY .. "  ⏭ " .. skip .. " ignorada(s)" .. RESET .. "\n") end
  io.write("\n")
end

function M.usage()
  io.write(CYAN .. "\nUso:" .. RESET .. "\n")
  io.write("  TermAI npx " .. BOLD .. "@pacote" .. RESET .. " install " .. DIM .. "--skill nome [--g|--ag main]" .. RESET .. "\n")
  io.write("  TermAI npx " .. BOLD .. "skills add" .. RESET .. " <url> " .. DIM .. "--skill nome [--g|--ag main]" .. RESET .. "\n")
  io.write("  TermAI npx " .. BOLD .. "@pacote" .. RESET .. " install " .. DIM .. "--update --skill nome [--g]" .. RESET .. "\n")
  io.write("\n")
end

return M