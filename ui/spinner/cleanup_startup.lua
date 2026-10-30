-- ui/spinner/cleanup_startup.lua — startup: flags locais + spinner compartilhado + payloads por PID (#204).
local M = {}

local function pid_alive(pid)
  local f = io.open("/proc/" .. tostring(pid) .. "/stat", "r")
  if not f then return false end
  local s = f:read("*l") or ""; f:close()
  local state = s:match("^%d+ %S+ (%S)")
  return state ~= nil and state ~= "Z"
end

function M.run(tmpdir, opts)
  opts = opts or {}
  if opts.inject then os.remove(opts.inject) end
  if opts.reasoning then os.remove(opts.reasoning) end
  if opts.stream then os.remove(opts.stream) end
  if opts.spin_sh then os.remove(opts.spin_sh) end
  os.remove(tmpdir .. "/ta_tool_draw.flag")

  -- Slot compartilhado ta_pid: só mata se for o spinner (nunca outro processo).
  local pid_path = tmpdir .. "/ta_pid"
  local pf = io.open(pid_path, "r")
  if pf then
    local pid = pf:read("*l"); pf:close()
    if pid and pid:match("^%d+$") then
      if opts.is_spinner and opts.is_spinner(pid) then
        if opts.kill_orphan_spinner then opts.kill_orphan_spinner() end
      else
        -- não é spinner (ou morto sem cmdline): só remove o arquivo
        os.remove(pid_path)
      end
    else
      os.remove(pid_path)
    end
  end

  -- Payloads: ta_payload_<pid>_* só se dono morto; legado sem pid remove.
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
