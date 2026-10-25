-- tests/bash_patterns_bug/02_6_heredoc_corrigido.lua — parte de bash_patterns_bug.lua (ver fachada).
local harness = require("tests.helpers.harness")

local M = {}

function M.run()

  local function T(n, ok, d) if ok then harness.pass=harness.pass+1 else harness.fail=harness.fail+1; print("  FAIL: "..n..(d and (" — "..d) or "")) end end
  local function sec(t) print("\n=== "..t.." ===") end

  -- Helpers replicados (testam lógica isolada, sem dependências de config)
  local function wildcard_to_pattern(wc)
    local p = wc:gsub("[%^%$%(%)%%%.%[%]%+%-%?]", "%%%1")
    p = p:gsub("%*", ".*")
    return "^" .. p .. "$"
  end

  local function matches_rule(cmd, pattern)
    cmd = cmd:lower():match("^%s*(.-)%s*$") or cmd:lower()
    pattern = pattern:lower():match("^%s*(.-)%s*$") or pattern:lower()
    local prefix = pattern:match("^(.-):%*$")
    if prefix then
      prefix = prefix:match("^%s*(.-)%s*$") or prefix
      return cmd == prefix or cmd:sub(1, #prefix + 1) == prefix .. " "
    end
    if pattern:find("*", 1, true) then
      return cmd:match(wildcard_to_pattern(pattern)) ~= nil
    end
    return cmd == pattern
  end

  local SAFE_COMMANDS = {
    cd=true, ls=true, echo=true, cat=true, mkdir=true, chmod=true,
    grep=true, find=true, luac=true, lua=true, ["lua5.4"]=true,
    python=true, node=true, du=true, df=true, uptime=true, date=true,
    wc=true, ps=true, tail=true, head=true, awk=true, clear=true,
    pgrep=true, test=true, git=true
  }

  -- ═══════ 1. PARSER ═══════
  local parser = require("agent.hooks.bash_patterns.parser")

  local function fluxo(cmd, saved)
    local subcmds = parser.extract_subcommands(cmd)
    if #subcmds == 0 then return true, nil end
    for _, sub in ipairs(subcmds) do
      local trim = sub:match("^%s*(.-)%s*$") or sub
      local primary = trim:match("^%s*(%S+)") or ""
      if SAFE_COMMANDS[primary] then -- ok
      else
        local matched = false
        for _, p in ipairs(saved or {}) do
          if matches_rule(trim, p) then matched = true; break end
        end
        if not matched then return false, trim end
      end
    end
    return true, nil
  end


  sec("6. heredoc (corrigido)")
  local ok_h, fail_h = fluxo("cat << 'EOF' > /tmp/t.txt\nconteudo\nEOF", {"cat *"})
  T("cat heredoc = PASS (conteúdo ignorado)", ok_h,
    "failed: " .. tostring(fail_h))
  T("failed_sub é nil (heredoc tratado como dado)", fail_h == nil)
  -- ═══════ 7. ADVERSARIAL (heredocs) ═══════
  sec("7. adversarial")
  -- Heredoc com <<-
  T("heredoc: <<- com tab", fluxo("cat <<-'EOF' > /tmp/t.txt\nconteudo\nEOF", {"cat *"}))
  -- Heredoc com delimiter quoted
  T("heredoc: delimiter quoted", fluxo('cat << "MYEOF" > /tmp/t.txt\nconteudo\nMYEOF', {"cat *"}))
  -- Heredoc multiline
  T("heredoc: multi linha", fluxo("cat << 'EOF' > /tmp/t.txt\nlinha1\nlinha2\nlinha3\nEOF", {"cat *"}))
  -- Heredoc sem redirect
  T("heredoc: sem redirect", fluxo("cat << 'EOF'\nconteudo\nEOF", {"cat *"}))
  -- echo com heredoc
  T("heredoc: echo", fluxo("echo << 'EOF' > /tmp/t.txt\ntexto\nEOF", {}))
  -- Heredoc + comando normal
  T("heredoc: mixed", fluxo("cat << 'EOF' > /tmp/t.txt\nconteudo\nEOF; echo OK", {"cat *"}))
  T("espaços extras", matches_rule("  rm -f file  ", "rm *"))
  T("comando gigante", pcall(parser.extract_subcommands, "echo " .. string.rep("a", 10000)))
  T("aspas duplas com simples", #parser.extract_subcommands([[echo "hello 'world'" ]]) == 1)

  -- ═══════ 8. HUNTER BUGFIXES (Bugs 1-4) ═══════
end

return M
