local M = {}

M.c = {
  reset = "\27[0m", bold = "\27[1m", dim = "\27[2m",
  green = "\27[38;5;114m", yellow = "\27[38;5;220m",
  red = "\27[38;5;203m", cyan = "\27[38;5;80m",
  blue = "\27[38;5;39m", gray = "\27[38;5;245m",
  white = "\27[38;5;255m", orange = "\27[38;5;208m",
}

local c = M.c

function M.header(title)
  io.write("\n" .. c.bold .. c.cyan .. "  " .. title .. c.reset .. "\n")
  io.write(c.gray .. "  " .. string.rep("─", 45) .. c.reset .. "\n\n")
end

function M.prompt_read(label)
  io.write(c.cyan .. "  " .. label .. ": " .. c.reset)
  local ok, val = pcall(io.read)
  if not ok then return nil end
  return val
end

function M.fmt_ctx(n)
  if not n then return "?" end
  if n >= 1000000 then return string.format("%.1fM", n / 1000000)
  elseif n >= 1000 then return string.format("%.0fK", n / 1000)
  else return tostring(n) end
end

function M.pause()
  io.write(c.gray .. "\n  Pressione Enter para continuar..." .. c.reset)
  pcall(io.read)
end

function M.is_cancel(s)
  return not s or s == "" or s == "0"
end

function M.update_config_model(config_mod, ref)
  config_mod.set("agents.defaults.model.primary", ref)
end

return M
