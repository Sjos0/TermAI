-- commands/config/menus/web_tools/nucleo_1.lua — helpers internos: cls, row.
return function(M)
  local P = require("commands.config.menus.web_tools.nucleo")(M)
  local c = P.c


  local function cls() io.write("\27[2J\27[H"); io.flush() end


  local function row(label, value, color)
    color = color or c.white
    io.write(string.format("  %s%-22s%s %s%s%s\n",
      c.gray, label, c.reset, color, tostring(value), c.reset))
  end
  local N = {}
  for k, v in pairs(P) do N[k] = v end
  N.cls = cls
  N.row = row
  return N
end
