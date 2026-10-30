-- ui/spinner/cleanup_startup.lua — limpeza de startup escopada por PID (#204).
local M = {}

local function pid_alive(pid)
  local f = io.open("/proc/" .. tostring(pid) .. "/stat", "r")
  if not f then return false end
  local s = f:read("*l") or ""; f:close()
  local state = s:match("^%d+ %S+ (%S)")
  return state ~= nil and state ~= "Z"
end

local function is_spinner(pid)
  local f = io.open("/proc/" .. tostring(pid) .. "/cmdline", "r")
  if not f then return false end
  local cmdline = f:read("*a") or ""; f:close()
  return cmdline:find("ta_spin", 1, true) ~= nil
end

function M.run(tmpdir)
  local h = io.popen("ls -1 " .. tmpdir .. "/ta_pid_* " .. tmpdir .. "/ta_pid 2>/dev/null")
  if h then
    for line in h:lines() do
      local pid = line:match("ta_pid_(%d+)$")
      if not pid and line:match("ta_pid$") then
        local pf = io.open(line, "r")
        local oldpid = pf and pf:read("*l"); if pf then pf:close() end
        if oldpid and oldpid:match("^%d+$") then
          if not pid_alive(oldpid) then
            if is_spinner(oldpid) then os.execute("kill -TERM " .. oldpid .. " 2>/dev/null") end
            os.remove(line)
          elseif not is_spinner(oldpid) then
            os.remove(line)
          end
        else
          os.remove(line)
        end
      elseif pid and not pid_alive(pid) then
        if is_spinner(pid) then os.execute("kill -TERM " .. pid .. " 2>/dev/null") end
        os.remove(line)
        for _, suf in ipairs({
          "/ta_spin_" .. pid .. ".sh",
          "/ta_inject_" .. pid .. ".flag",
          "/ta_reasoning_" .. pid .. ".flag",
          "/termai_stream_" .. pid .. ".flag",
          "/termai_frames_" .. pid .. ".txt",
          "/termai_rows_" .. pid .. ".txt",
        }) do os.remove(tmpdir .. suf) end
        local ph = io.popen("rm -f " .. tmpdir .. "/ta_payload_" .. pid .. "_* 2>/dev/null")
        if ph then ph:close() end
      end
    end
    h:close()
  end
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
