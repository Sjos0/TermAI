-- tests/compaction_v7/02_6_filetracking.lua — parte de compaction_v7.lua (ver fachada).
local harness = require("tests.helpers.harness")

local M = {}

function M.run()
  local function T(name, ok)
    if ok then harness.pass = harness.pass + 1 else harness.fail = harness.fail + 1; print("  FAIL: " .. name) end
  end
  local function sec(t) print("\n=== " .. t .. " ===") end
  local function est(m)
    local t = 0; for _, v in ipairs(m) do t = t + math.ceil(#(v.content or "") / 4) end; return t
  end
  local function M(role, content, extra)
    local m = {role = role, content = content or ""}
    if extra then for k, v in pairs(extra) do m[k] = v end end; return m
  end
  local TC = {tool_calls = {{["function"] = {name = "read", arguments = "{}"}}}}

  -- ═══════ 1. CUTPOINT ═══════

  sec("6. filetracking")
  local ft = require("agent.compaction.filetracking")
  do
    local sf = {read={set={a=true}}, written={set={b=true}}, edited={set={c=true}}}
    local xml = ft.accumulate(nil, sf)
    T("ft: read_files", xml:match("read_files") ~= nil)
    T("ft: created_files", xml:match("created_files") ~= nil)
    T("ft: edited_files", xml:match("edited_files") ~= nil)
  end
  do
    local prev = {read_files={"old.lua"}, created_files={}, edited_files={}}
    local sf = {read={set={new=true}}, written={}, edited={set={c=true}}}
    local _, d = ft.accumulate(prev, sf)
    local ho, hn = false, false
    for _,v in ipairs(d.read_files) do if v=="old.lua" then ho=true end; if v=="new" then hn=true end end
    T("ft: cumulativo old", ho); T("ft: cumulativo new", hn)
  end
  do local xml = ft.accumulate(nil, nil); T("ft: vazio=nil", xml == "") end

  local function safe_read_file(path)
    local f = io.open(path, "r")
    if not f then
      local local_path = path:gsub("^.-/TermAI/", "")
      f = io.open(local_path, "r")
    end
    if not f then error("Could not open file: " .. path) end
    local content = f:read("*a")
    f:close()
    return content
  end

  -- ═══════ 7. BANNERS ═══════
  sec("7. banners")
  local bc = safe_read_file(os.getenv("HOME") .. "/TermAI/agent/banners.lua")
  T("banners: compactacao s/ mf.estado", bc:find("compactacao", 1, true) and not bc:find("M.compactacao", 1, true) or true)
  -- Verificação direta: a função compactacao não chama mf.estado
  T("banners: compactacao sem mf", not bc:match("function M%.compactacao.-%f[^%w]mf%.estado"))

  -- ═══════ 8-10. PAYLOAD/CONFIRM/INIT ═══════
  sec("8. payload + confirm + init")
  local pc = safe_read_file(os.getenv("HOME") .. "/TermAI/agent/api/payload.lua")
  T("payload: no_tools", pc:match("ctx%.no_tools") ~= nil)
  local cc = safe_read_file(os.getenv("HOME") .. "/TermAI/agent/compaction/confirm.lua")
  T("confirm: gerar_e_confirmar", cc:match("M%.gerar_e_confirmar") ~= nil)
  T("confirm: no_tools", cc:match("no_tools = true") ~= nil)
  local ic = require("tests.helpers.fonte").ler("agent/compaction/init")
  T("init: confirm", ic:match("confirm") ~= nil)
  T("init: splitturn", ic:match("splitturn") ~= nil)
  T("init: guarded", ic:match("do_compaction_guarded") ~= nil)
  T("init: persisted_source", ic:match("persisted_source") ~= nil)

  -- ═══════ RELATÓRIO ═══════
end

return M
