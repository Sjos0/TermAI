-- tests/permissions_matcher_spec.lua — Testes unitários do módulo matcher (PR #33 / Issue #26)
-- Executar: lua5.4 tests/permissions_matcher_spec.lua  (a partir da raiz do repo)
package.path = "./?.lua;./?/init.lua;" .. package.path

local matcher = require("tools.exec.permissions.matcher")

local pass, fail = 0, 0
local function T(name, ok, detail)
  if ok then
    pass = pass + 1
    print("  ✅ " .. name)
  else
    fail = fail + 1
    print("  ❌ " .. name .. (detail and (" — " .. detail) or ""))
  end
end

local function sec(title)
  print("\n=== " .. title .. " ===")
end

-- ============================================================================
-- 1. wildcard_to_pattern
-- ============================================================================
sec("1. wildcard_to_pattern")

T("sort * → ^sort$", matcher.wildcard_to_pattern("sort *") == "^sort$")
T("* → ^.*$", matcher.wildcard_to_pattern("*") == "^.*$")
T("rm * → ^rm$", matcher.wildcard_to_pattern("rm *") == "^rm$")
T("sem curinga: echo → ^echo$", matcher.wildcard_to_pattern("echo") == "^echo$")
T("prefixo com caracteres especiais escapados", matcher.wildcard_to_pattern("a.b *") == "^a%.b$")
T("múltiplos * no meio (sem trailing space*)", matcher.wildcard_to_pattern("foo*bar") == "^foo.*bar$")

-- ============================================================================
-- 2. matches_rule — casos básicos e case-insensitive
-- ============================================================================
sec("2. matches_rule — básicos")

T("sort bate 'sort *'", matcher.matches_rule("sort", "sort *") == true)
T("sorteo NÃO bate 'sort *'", matcher.matches_rule("sorteo", "sort *") == false)
T("SORT -rn bate 'sort *' (case-insensitive)", matcher.matches_rule("SORT -rn", "sort *") == true)
T("sort -rn bate 'sort *'", matcher.matches_rule("sort -rn", "sort *") == true)
T("echo hello bate 'echo *'", matcher.matches_rule("echo hello", "echo *") == true)
T("echo NÃO bate 'sort *'", matcher.matches_rule("echo", "sort *") == false)

-- ============================================================================
-- 3. matches_rule — prefixo com ":" (rm:*)
-- ============================================================================
sec("3. matches_rule — prefixo :*")

T("rm -rf /tmp bate 'rm:*'", matcher.matches_rule("rm -rf /tmp", "rm:*") == true)
T("rm bate 'rm:*'", matcher.matches_rule("rm", "rm:*") == true)
T("rmdir NÃO bate 'rm:*'", matcher.matches_rule("rmdir", "rm:*") == false)
T("rmx NÃO bate 'rm:*'", matcher.matches_rule("rmx", "rm:*") == false)
T("RM -f file bate 'rm:*' (case-insensitive)", matcher.matches_rule("RM -f file", "rm:*") == true)

-- ============================================================================
-- 4. matches_rule — padrão vazio e exatos
-- ============================================================================
sec("4. matches_rule — borda e exatos")

T("padrão vazio → false", matcher.matches_rule("ls", "") == false)
T("padrão só espaços → false", matcher.matches_rule("ls", "   ") == false)
T("cmd == pattern exato", matcher.matches_rule("git status", "git status") == true)
T("cmd != pattern exato", matcher.matches_rule("git status", "git commit") == false)
T("espaços laterais são trimados", matcher.matches_rule("  ls  ", "ls") == true)
T("pattern com espaços laterais", matcher.matches_rule("ls", "  ls  ") == true)

-- ============================================================================
-- 5. matches_rule — wildcards genéricos (*)
-- ============================================================================
sec("5. matches_rule — wildcards genéricos")

T("foo*bar bate 'foobar'", matcher.matches_rule("foobar", "foo*bar") == true)
T("foo*bar bate 'fooXXXbar'", matcher.matches_rule("fooXXXbar", "foo*bar") == true)
T("foo*bar NÃO bate 'foobaz'", matcher.matches_rule("foobaz", "foo*bar") == false)
T("'*' bate qualquer coisa", matcher.matches_rule("qualquer coisa", "*") == true)

print("\nRESULTADO: " .. pass .. " passaram, " .. fail .. " falharam")
if fail > 0 then os.exit(1) end
