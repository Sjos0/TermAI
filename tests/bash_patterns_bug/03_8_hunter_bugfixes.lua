-- tests/bash_patterns_bug/03_8_hunter_bugfixes.lua — parte de bash_patterns_bug.lua (ver fachada).
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


  sec("8. hunter bugfixes")

  -- Bug 1: Variable assignments trigger permission prompts (variable assignments are NOT commands)
  local single_assignment = "JULES_KEY=\"AQ.Ab8...\" GH_KEY=\"ghp_7Nc...\" BASE=\"https://jules.googleapi...\""
  T("Bug 1: extract_subcommands on pure variable assignment should be empty", #parser.extract_subcommands(single_assignment) == 0)
  T("Bug 1: fluxo on pure variable assignment should auto-approve", fluxo(single_assignment, {}))

  -- Bug 2: Comments trigger permission prompts (comments should be completely ignored)
  local comment_cmd = "# This is a comment\necho \"hello\""
  local comment_subcmds = parser.extract_subcommands(comment_cmd)
  T("Bug 2: extract_subcommands should ignore comments completely", #comment_subcmds == 1 and comment_subcmds[1] == 'echo "hello"')
  T("Bug 2: fluxo with comment followed by safe command should auto-approve", fluxo(comment_cmd, {}))

  local pure_comment = "# This is a comment only"
  T("Bug 2: extract_subcommands should be empty for pure comment", #parser.extract_subcommands(pure_comment) == 0)
  T("Bug 2: fluxo on pure comment should auto-approve", fluxo(pure_comment, {}))

  local comment_after_semicolon = "echo hello; # some comment"
  local comment_after_semi_subcmds = parser.extract_subcommands(comment_after_semicolon)
  T("Bug 2: extract_subcommands should ignore comment after semicolon", #comment_after_semi_subcmds == 1 and comment_after_semi_subcmds[1] == 'echo hello')

  -- Bug 3: Multiple variable assignments on one line
  local multi_assignment = "JULES_KEY=\"...\" GH_KEY=\"...\" BASE=\"...\" curl -s ..."
  local multi_subcmds = parser.extract_subcommands(multi_assignment)
  T("Bug 3: extract_subcommands strips all leading assignments", #multi_subcmds == 1 and multi_subcmds[1] == "curl -s ...")

  -- Bug 4: Safe commands like echo combined with variable assignments or other syntax
  local mixed_cmd_echo = "VAR=value echo hello"
  local mixed_subcmds = parser.extract_subcommands(mixed_cmd_echo)
  T("Bug 4: extract_subcommands on mixed command strips assignment", #mixed_subcmds == 1 and mixed_subcmds[1] == "echo hello")
  T("Bug 4: fluxo with assignment + safe command should auto-approve", fluxo(mixed_cmd_echo, {}))

  -- Complex and edge case assignments
  local quoted_var = "VAR='a b c' echo 'hello'"
  local quoted_var_subcmds = parser.extract_subcommands(quoted_var)
  T("Complex: quoted var assignment is stripped", #quoted_var_subcmds == 1 and quoted_var_subcmds[1] == "echo 'hello'")

  local double_quoted_var = "A=\"1 2 3\" B='4 5' C=6 echo hello"
  local double_quoted_subcmds = parser.extract_subcommands(double_quoted_var)
  T("Complex: multiple quoted and unquoted vars are stripped", #double_quoted_subcmds == 1 and double_quoted_subcmds[1] == "echo hello")


  -- ═══════ RELATÓRIO ═══════
end

return M
