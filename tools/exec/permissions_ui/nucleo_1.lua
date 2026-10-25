-- tools/exec/permissions_ui/nucleo_1.lua — helpers internos: get_wall_time, enter_modal_screen, leave_modal_screen, display_text, compute_suggested_pattern.
return function(M)
  local P = require("tools.exec.permissions_ui.nucleo")(M)
  local suggest = P.suggest


  local function get_wall_time()
    local f = io.open("/proc/uptime", "r")
    if not f then return os.time() end
    local val = f:read("*n")
    f:close()
    return val or os.time()
  end


  -- ── Alternate screen (modal) ───────────────────────────────────────────────
  -- DECSET 1049: salva cursor + entra na tela alternativa.
  -- DECRST 1049: restaura tela principal + cursor.
  -- O terminal cuida de scroll/wrap — não precisamos simular viewport.

  local function enter_modal_screen()
    io.write("\27[?1049h")  -- alternate screen buffer
    io.write("\27[2J\27[H") -- clear + cursor home
    io.flush()
  end


  local function leave_modal_screen()
    io.write("\27[0m")      -- reset attributes
    io.write("\27[?1049l")  -- back to main screen
    io.flush()
  end


  local function display_text(s)
    s = tostring(s or "")
    s = s:gsub("[\r\n]+", "·"):gsub("[\1-\31]", "·")
    if #s > 120 then s = s:sub(1, 117) .. "..." end
    return s
  end


  local function compute_suggested_pattern(tool_name, command, failed_sub)
    if tool_name ~= "Exec" then return "" end
    local target = failed_sub or command
    local suggested_pattern = suggest.get_suggested_pattern(target)
    if suggested_pattern == ""
       or suggested_pattern:match("^%s*%*?%s*$")
       or suggested_pattern:match("^\\%s*%*")
       or not suggested_pattern:match("%w") then
      return ""
    end
    return suggested_pattern
  end
  local N = {}
  for k, v in pairs(P) do N[k] = v end
  N.get_wall_time = get_wall_time
  N.enter_modal_screen = enter_modal_screen
  N.leave_modal_screen = leave_modal_screen
  N.display_text = display_text
  N.compute_suggested_pattern = compute_suggested_pattern
  return N
end
