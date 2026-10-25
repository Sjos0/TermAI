-- tests/disabled_tools_spec/03_parte.lua — parte de disabled_tools_spec.lua (ver fachada).
local harness = require("tests.helpers.harness")

local M = {}

function M.run()


  local function T(name, ok, detail)
    if ok then
      harness.pass = harness.pass + 1
      print("  OK  " .. name)
    else
      harness.fail = harness.fail + 1
      print("  FAIL: " .. name .. (detail and (" — " .. tostring(detail)) or ""))
    end
  end

  local function sec(title)
    print("\n=== " .. title .. " ===")
  end

  local tools = require("tools")

  -- Nomes reais do registry (ordem não garantida em pairs)

  local all_names = {}
  for name in pairs(tools.registry) do
    all_names[#all_names + 1] = name
  end
  table.sort(all_names)
  local sample = all_names[1]

  local sample2 = all_names[2] or all_names[1]


  -- ─────────────────────────────────────────────────────────────

  local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a") or ""
    f:close()
    return s
  end

  local payload_src = read_file("agent/api/payload.lua") or read_file("./agent/api/payload.lua")
  local context_src = read_file("agent/context.lua") or read_file("./agent/context.lua")
  local tools_src = read_file("tools.lua") or read_file("./tools.lua")
  local runner_src = require("tests.helpers.fonte").ler("agent/loop/tool_runner/executor")
    or read_file("./agent/loop/tool_runner/executor.lua")
  local xml_src = read_file("agent/loop/xml_path.lua") or read_file("./agent/loop/xml_path.lua")
  local th_exec_src = read_file("agent/tools_handler/executor.lua")
    or read_file("./agent/tools_handler/executor.lua")

  if payload_src then
    T("payload passa ctx.disabled_tools a get_schema",
      payload_src:find("get_schema%(ctx%.disabled_tools%)") ~= nil)
    T("payload respeita ctx.no_tools soberano",
      payload_src:find("not ctx%.no_tools") ~= nil or payload_src:find("ctx%.no_tools") ~= nil)
  else
    T("payload.lua legível no cwd", false, "rode da raiz do clone")
  end

  if context_src then
    T("context popula disabled_tools",
      context_src:find("disabled_tools") ~= nil)
    T("context popula agent_id",
      context_src:find("agent_id") ~= nil)
    T("context resolve agente por list[1].id (não hardcode exclusivo)",
      context_src:find("list%[1%]") ~= nil
      or context_src:find("get_agent") ~= nil)
  else
    T("context.lua legível no cwd", false, "rode da raiz do clone")
  end

  if tools_src then
    T("tools.lua documenta get_schema com disabled",
      tools_src:find("get_schema%(disabled%)") ~= nil
      or tools_src:find("function tools%.get_schema") ~= nil)
    T("tools.lua tem to_disabled_set (set + array)",
      tools_src:find("to_disabled_set") ~= nil)
  else
    T("tools.lua legível no cwd", false)
  end

  -- #49: hot path do runner deve propagar ctx.disabled_tools
  if runner_src then
    T("runner individual passa disabled_tools a call_structured",
      runner_src:find("disabled_tools%s*=%s*ctx%.disabled_tools") ~= nil)
    local count = 0
    for _ in runner_src:gmatch("disabled_tools%s*=%s*ctx%.disabled_tools") do
      count = count + 1
    end
    T("runner propaga disabled_tools em individual e grupo Read",
      count >= 2, "ocorrências=" .. tostring(count))
  else
    T("tool_runner/executor.lua legível no cwd", false)
  end

  if xml_src then
    T("xml_path passa ctx.disabled_tools a th.executar",
      xml_src:find("executar%(ferramentas,%s*ctx%.disabled_tools%)") ~= nil)
  else
    T("xml_path.lua legível no cwd", false)
  end

  if th_exec_src then
    T("tools_handler/executor aceita disabled_tools no call",
      th_exec_src:find("tools%.call%([^,]+,%s*disabled_tools%)") ~= nil
      or th_exec_src:find("tools%.call%(.-disabled_tools%)") ~= nil)
  else
    T("tools_handler/executor.lua legível no cwd", false)
  end

  -- ─────────────────────────────────────────────────────────────
end

return M
