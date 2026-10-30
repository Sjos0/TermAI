-- ui/spinner/cleanup_startup.lua — só mata spinner de dono morto (#222).
local M = {}

local function pid_alive(pid)
  -- Sem /proc: lado seguro = não matar.
  local f = io.open("/proc/" .. tostring(pid) .. "/stat", "r")
  if not f then return false end
  local s = f:read("*l") or ""; f:close()
  local state = s:match("^%d+ %S+ (%S)")
  return state ~= nil and state ~= "Z"
end

local function kill_spinner_pid(pid, is_spinner)
  if not is_spinner or not is_spinner(pid) then return end
  os.execute("kill -TERM " .. pid .. " 2>/dev/null")
  os.execute("kill -KILL " .. pid .. " 2>/dev/null")
end

function M.run(tmpdir, opts)
  opts = opts or {}
  if opts.inject then os.remove(opts.inject) end
  if opts.reasoning then os.remove(opts.reasoning) end
  if opts.stream then os.remove(opts.stream) end
  if opts.spin_sh then os.remove(opts.spin_sh) end
  os.remove(tmpdir .. "/ta_tool_draw.flag")

  -- ta_pid_<dono>: só limpa se o dono estiver morto.
  local h = io.popen("ls -1 " .. tmpdir .. "/ta_pid_* " .. tmpdir .. "/ta_pid 2>/dev/null")
  if h then
    for path in h:lines() do
      local owner = path:match("ta_pid_(%d+)$")
      local pf = io.open(path, "r")
      local spin_pid = pf and pf:read("*l"); if pf then pf:close() end
      if owner then
        if not pid_alive(owner) then
          if spin_pid and spin_pid:match("^%d+$") then
            kill_spinner_pid(spin_pid, opts.is_spinner)
          end
          os.remove(path)
          os.remove(tmpdir .. "/ta_spin_" .. owner .. ".sh")
        end
        -- dono vivo: não tocar
      else
        -- legado ta_pid sem sufixo: só limpa se o spinner apontado estiver morto
        -- ou se não for spinner
        if spin_pid and spin_pid:match("^%d+$") then
          if opts.is_spinner and opts.is_spinner(spin_pid) then
            if not pid_alive(spin_pid) then
              kill_spinner_pid(spin_pid, opts.is_spinner)
              os.remove(path)
            end
            -- spinner vivo legado: deixar (outra instância antiga)
          else
            os.remove(path)
          end
        else
          os.remove(path)
        end
      end
    end
    h:close()
  end

  -- Payloads: ta_payload_<pid>_* só se dono morto
  local ph = io.popen("ls -1 " .. tmpdir .. "/ta_payload_* 2>/dev/null")
  if ph then
    for line in ph:lines() do
      local owner = line:match("ta_payload_(%d+)_")
      if owner then
        if not pid_alive(owner) then os.remove(line) end
      else
        os.remove(line)
      end
    end
    ph:close()
  end
end

return M
