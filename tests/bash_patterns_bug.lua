-- bash_patterns_bug.lua — Testes para bug de persistência de permissões
-- Executar: lua5.4 ~/TermAI/tests/bash_patterns_bug.lua
package.path = "./?.lua;./?/init.lua;" .. os.getenv("HOME") .. "/TermAI/?.lua;" .. os.getenv("HOME") .. "/TermAI/?/init.lua;" .. package.path

local pass, fail = 0, 0
local function T(n, ok, d) if ok then pass=pass+1 else fail=fail+1; print("  FAIL: "..n..(d and (" — "..d) or "")) end end
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
sec("1. parser")
local parser = require("agent.hooks.bash_patterns.parser")

T("simples: echo hello", #parser.extract_subcommands("echo hello") == 1)
T("redirect: rm 2>/dev/null", #parser.extract_subcommands("rm -f /tmp/x 2>/dev/null") == 1)
T("semicolon: a; b", #parser.extract_subcommands("rm -f /tmp/x; echo OK") == 2)
T("and: a && b", #parser.extract_subcommands("echo a && echo b") == 2)
T("pipe: a | b", #parser.extract_subcommands("cat f | grep x") == 2)
T("vazio", #parser.extract_subcommands("") == 0)
T("heredoc: cat << EOF", #parser.extract_subcommands("cat << 'EOF' > /tmp/t.txt\nconteudo\nEOF") >= 1)

-- ═══════ 2. SUGGEST ═══════
sec("2. suggest")
local suggest = require("agent.hooks.bash_patterns.suggest")

T("echo hello -> 'echo *'", suggest.get_suggested_pattern("echo hello") == "echo *")
T("lua script.lua -> 'lua script.lua *'", suggest.get_suggested_pattern("lua script.lua") == "lua script.lua *")
T("lua5.4 x.lua -> 'lua5.4 x.lua *'", suggest.get_suggested_pattern("lua5.4 x.lua") == "lua5.4 x.lua *")
T("git commit -> 'git commit *'", suggest.get_suggested_pattern("git commit") == "git commit *")
T("rm -f file -> 'rm *'", suggest.get_suggested_pattern("rm -f file") == "rm *")
T("cat file > out -> 'cat *'", suggest.get_suggested_pattern("cat file > out") == "cat *")
T("cat f | grep x -> 'cat *'", suggest.get_suggested_pattern("cat f | grep x") == "cat *")
T("vazio -> ''", suggest.get_suggested_pattern("") == "")
T("X=1 cmd -> 'cmd *'", suggest.get_suggested_pattern("X=1 cmd") == "cmd *")

-- ═══════ 3. MATCHING ═══════
sec("3. matching")

T("wildcard: 'rm *' -> '^rm .*$'", wildcard_to_pattern("rm *") == "^rm .*$")
T("wildcard: 'echo *' -> '^echo .*$'", wildcard_to_pattern("echo *") == "^echo .*$")

T("match: echo = 'echo'", matches_rule("echo", "echo"))
T("match: rm -f file bate 'rm *'", matches_rule("rm -f file", "rm *"))
T("match: echo hello bate 'echo *'", matches_rule("echo hello", "echo *"))
T("match: cat file bate 'cat *'", matches_rule("cat file.txt", "cat *"))
T("match: rm:* prefix", matches_rule("rm -rf /tmp", "rm:*"))
T("match: case insensitive", matches_rule("RM -f file", "rm *"))
T("match: rmdir NÃO bate 'rm *'", not matches_rule("rmdir x", "rm *"))
T("match: pattern vazio NÃO bata", not matches_rule("echo hi", ""))

-- ═══════ 4. SAFE_COMMANDS ═══════
sec("4. SAFE_COMMANDS")
T("SAFE: echo", SAFE_COMMANDS["echo"] == true)
T("SAFE: cat", SAFE_COMMANDS["cat"] == true)
T("SAFE: lua5.4", SAFE_COMMANDS["lua5.4"] == true)
T("NOT SAFE: rm", SAFE_COMMANDS["rm"] == nil)
T("NOT SAFE: mv", SAFE_COMMANDS["mv"] == nil)

-- ═══════ 5. INTEGRAÇÃO ═══════
sec("5. integração (parser→match)")

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

T("echo = auto-approve", fluxo('echo "hello"', {}))
T("rm+padrão = auto-approve", fluxo("rm -f /tmp/x", {"rm *"}))
T("rm s/padrão = precisa approve", not fluxo("rm -f /tmp/x", {}))
T("rm+redirect+padrão = auto-approve", fluxo("rm -f /tmp/x 2>/dev/null", {"rm *"}))
T("echo(safe)+rm(padrao) = ok", fluxo('echo "ok"; rm -f /tmp/x', {"rm *"}))
T("echo(safe)+rm(s/padrao) = precisa rm", not fluxo('echo "ok"; rm -f /tmp/x', {}))
-- Comandos reais do usuário
T("echo &&&&", fluxo('echo "a" && echo "b"', {}))
T("cat arquivo", fluxo("cat arquivo.txt", {}))
T("rm+redirect s/padrao", not fluxo("rm -f ~/x 2>/dev/null; echo OK", {}))
T("rm+redirect c/padrao", fluxo("rm -f ~/x 2>/dev/null; echo OK", {"rm *"}))
-- ═══════ 6. BUG CORRIGIDO: HEREDOC ═══════
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
print("\n" .. string.rep("═", 60))
print(string.format("RESULTADO: %d passaram, %d falharam (total: %d)", pass, fail, pass + fail))
print(string.rep("═", 60))
if fail > 0 then os.exit(1) end
