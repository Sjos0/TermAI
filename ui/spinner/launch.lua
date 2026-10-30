-- ui/spinner/launch.lua — scripts shell embutidos + start/kill do spinner.
-- Slot ta_pid_<dono>: cada instância só toca o próprio arquivo (#222).
local M = {}

local TMPDIR = os.getenv("TMPDIR") or "/data/data/com.termux/files/usr/tmp"

local function _my_pid()
  local f = io.open("/proc/self/stat", "r")
  if not f then return "0" end
  local s = f:read("*l") or ""; f:close()
  return s:match("^(%d+)") or "0"
end

local OWNER = _my_pid()
local _spin_sh        = TMPDIR .. "/ta_spin_" .. OWNER .. ".sh"
local _spin_pid       = TMPDIR .. "/ta_pid_" .. OWNER
local _inject_flag    = TMPDIR .. "/ta_inject.flag"
local _reasoning_flag = TMPDIR .. "/ta_reasoning.flag"
local _stream_flag    = TMPDIR .. "/termai_stream.flag"
local _frames_file    = TMPDIR .. "/termai_frames.txt"
local _rows_file      = TMPDIR .. "/termai_rows.txt"

local roteiros = require("ui.spinner.roteiros")
local SPINNER_SCRIPT, COMPACT_SCRIPT = roteiros.SPINNER_SCRIPT, roteiros.COMPACT_SCRIPT

local function _is_spinner(pid)
  local f = io.open("/proc/" .. pid .. "/cmdline", "r")
  if not f then return false end
  local cmdline = f:read("*a") or ""; f:close()
  return cmdline:find("ta_spin", 1, true) ~= nil
end

local function _kill_pid()
  -- Só o slot desta instância.
  local pid_f = io.open(_spin_pid, "r")
  if not pid_f then return end
  local pid = pid_f:read("*l")
  pid_f:close()
  if not (pid and pid:match("^%d+$")) then return end
  if not _is_spinner(pid) then
    os.remove(_spin_pid)
    return
  end
  os.execute("kill -TERM " .. pid .. " 2>/dev/null; kill -TERM -" .. pid .. " 2>/dev/null")
  os.execute("kill -KILL " .. pid .. " 2>/dev/null; kill -KILL -" .. pid .. " 2>/dev/null")
  os.remove(_spin_pid)
end

local function _write_and_launch(script)
  _kill_pid()
  local f = io.open(_spin_sh, "w")
  if not f then return end
  f:write(script)
  f:close()
  os.execute("sh -c 'sh \"" .. _spin_sh .. "\" 2>/dev/null & echo $! > \"" .. _spin_pid .. "\"'")
  io.flush()
end

function M.launch()
  _write_and_launch(SPINNER_SCRIPT)
end

function M.launch_compact()
  _write_and_launch(COMPACT_SCRIPT)
end

function M.kill_spinner()
  _kill_pid()
  os.remove(_spin_sh)
  os.remove(TMPDIR .. "/ta_tool_draw.flag")
  os.remove(_stream_flag)
  io.write("\r\27[K")
  io.flush()
end

function M.cleanup_turno()
  _kill_pid()
  os.execute("rm -f " .. _spin_pid .. " " .. _spin_sh
    .. " " .. _inject_flag .. " " .. _reasoning_flag .. " " .. _stream_flag
    .. " " .. _frames_file .. " " .. _rows_file
    .. " " .. TMPDIR .. "/ta_tool_draw.flag 2>/dev/null")
  io.write("\r\27[K")
  io.flush()
end

function M.cleanup_startup()
  require("ui.spinner.cleanup_startup").run(TMPDIR, {
    owner = OWNER,
    is_spinner = _is_spinner,
    inject = _inject_flag,
    reasoning = _reasoning_flag,
    stream = _stream_flag,
    spin_sh = _spin_sh,
  })
end

function M.set_inject_flag()
  local f = io.open(_inject_flag, "w")
  if f then f:write("1"); f:close() end
end

function M.clear_reasoning_flag()
  os.remove(_reasoning_flag)
end

function M.set_reasoning_flag()
  local f = io.open(_reasoning_flag, "w")
  if f then f:write("1"); f:close() end
end

return M
