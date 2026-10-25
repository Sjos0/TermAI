-- tests/compaction_v7/01_1_cutpoint.lua — parte de compaction_v7.lua (ver fachada).
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

  sec("1. cutpoint")
  local cp = require("agent.compaction.cutpoint")

  T("is_safe_cut: user=seguro", cp.is_safe_cut({M("user","x")}, 1))
  T("is_safe_cut: assistant s/tc=seguro", cp.is_safe_cut({M("assistant","x")}, 1))
  T("is_safe_cut: tool=inseguro", not cp.is_safe_cut({M("tool","x")}, 1))
  T("is_safe_cut: assistant+TC=inseguro", not cp.is_safe_cut({M("assistant","",TC)}, 1))
  T("is_safe_cut: idx nil=true", cp.is_safe_cut({M("user","x")}, nil))

  -- find_safe_keep_from
  T("safe_keep: [user,tool] w=1 -> 1", cp.find_safe_keep_from({M("user","a"), M("tool","b")}, 1) == 1)
  T("safe_keep: [user,asst+TC,tool,user] w=2 -> 4",
    cp.find_safe_keep_from({M("user","a"), M("assistant","",TC), M("tool","b"), M("user","c")}, 2) == 4)

  -- find_compaction_bounds: 84 msgs
  do
    local msgs = {M("system","prompt")}
    for i=1,3 do msgs[#msgs+1] = M("user","init"..i) end
    for i=1,20 do
      msgs[#msgs+1] = M("user", string.rep("x",100))
      msgs[#msgs+1] = M("assistant","",TC)
      msgs[#msgs+1] = M("tool", string.rep("y",200))
      msgs[#msgs+1] = M("assistant", string.rep("z",100))
    end
    local ss, se = cp.find_compaction_bounds(msgs, {anchor_keep=5, anchor_token_cap=8000, keep_recent_tokens=1000}, est)
    T("bounds: ss e se números", ss ~= nil and type(se) == "number")
    T("bounds: ss >= 0", ss and ss >= 0)
    T("bounds: se > ss", ss and type(se) == "number" and se > ss)
  end

  -- bounds: curto
  do
    local ss, se = cp.find_compaction_bounds({M("system","p"), M("user","a"), M("user","b")}, {anchor_keep=5}, est)
    T("bounds curto: nil", ss == nil)
    T("bounds curto: short_history", se == "short_history")
  end

  -- bounds: tudo cabe
  do
    local msgs = {M("system","p"), M("user","a"), M("user","b"), M("user","c")}
    local ss = cp.find_compaction_bounds(msgs, {anchor_keep=2, anchor_token_cap=8000, keep_recent_tokens=999999}, est)
    T("bounds tudo cabe: nil", ss == nil)
  end

  -- ═══════ 2. PODA ═══════
  sec("2. poda")
  local poda = require("agent.compaction.poda")

  do
    local msgs = {}; for i=1,10 do msgs[#msgs+1] = M("tool", string.rep("A", 900)) end
    T("poda: true quando poda", poda.poda_mecanica(msgs, 100, 500, est))
    local f = false; for _, m in ipairs(msgs) do if m.content and m.content:match("podados") then f=true end end
    T("poda: truncado", f)
  end
  do
    local msgs = {}; for i=1,5 do msgs[#msgs+1] = M("user","p"..i) end
    for i=1,3 do msgs[#msgs+1] = M("tool", string.rep("B", 900)) end
    T("poda: recente s/ podar", not poda.poda_mecanica(msgs, 50000, 500, est))
  end
  T("poda: vazia=false", not poda.poda_mecanica({}, 100, 500, est))
  T("poda: curto=false", not poda.poda_mecanica({M("tool","curto")}, 1, 500, est))

  -- ═══════ 3. SERIALIZE ═══════
  sec("3. serialize")
  local ser = require("agent.compaction.serialize")

  do
    local r = ser.serialize_messages({M("user","olá"), M("assistant","oi")})
    T("ser: [USUÁRIO]", r:match("%[USUÁRIO%]") ~= nil)
    T("ser: [AGENTE]", r:match("%[AGENTE%]") ~= nil)
  end
  do
    local r = ser.serialize_messages({M("assistant","vou ler", TC)})
    T("ser: tool_calls", r:match("Ferramenta") ~= nil)
    T("ser: nome", r:match("read") ~= nil)
  end
  T("ser: tool >2000 truncado", ser.serialize_messages({M("tool", string.rep("X",5000))}):match("truncados") ~= nil)
  T("ser: tool curto s/ truncar", not ser.serialize_messages({M("tool","ok")}):match("truncados"))
  T("ser: system", ser.serialize_messages({M("system","inst")}):match("SISTEMA") ~= nil)
  T("ser: nil content", ser.serialize_messages({{role="user", content=nil}}) ~= nil)

  -- ═══════ 4. SPLITTURN ═══════
  sec("4. splitturn")
  local st = require("agent.compaction.splitturn")
  T("split: user=safe_end", st.find_turn_start({M("system","p"), M("user","a"), M("user","b")}, 3, 1) == 3)
  T("split: assistant -> user(2)", st.find_turn_start({M("system","p"), M("user","a"), M("assistant","",TC), M("tool","r"), M("assistant","x")}, 5, 1) == 2)
  T("split: sem user=floor", st.find_turn_start({M("system","p"), M("assistant","x")}, 2, 1) == 1)

  -- ═══════ 5. SUMMARY_MERGE ═══════
  sec("5. summary_merge")
  local sm = require("agent.compaction.summary_merge")
  do local _, uc = sm.build_prompt("hist", nil, nil)
    T("prompt s/prev: sem RESUMO", not uc:match("RESUMO ANTERIOR"))
    T("prompt s/prev: tem HISTÓRICO", uc:match("HISTÓRICO") ~= nil) end
  do local _, uc = sm.build_prompt("novo", "antigo", nil)
    T("prompt c/prev: tem RESUMO", uc:match("RESUMO ANTERIOR") ~= nil)
    T("prompt c/prev: tem antigo", uc:match("antigo") ~= nil) end
  do local sp = sm.build_prompt("h", nil, "foco em bugs")
    T("prompt c/instr: aparece", sp:match("foco em bugs") ~= nil) end
  T("get_previous: erro=nil,nil", (function()
    local s,d = sm.get_previous({get_last_compaction=function() error("x") end})
    return s==nil and d==nil
  end)())

  -- ═══════ 6. FILETRACKING ═══════
end

return M
