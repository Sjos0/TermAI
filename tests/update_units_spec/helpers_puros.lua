-- :Helpers puros de update.lua (short_sha, trim_version, quote_base) reimplementados para o contrato.
local harness = require("tests.helpers.harness")
local T, sec = harness.T_so_falhas, harness.sec

local M = {}

function M.run()
  -- ─────────────────────────────────────────────────────────────
  -- Helpers puros (contratos extraídos de update.lua)
  -- ─────────────────────────────────────────────────────────────
  sec("helpers puros")

  local function short_sha(sha)
    if not sha or sha == "" then return "?" end
    return sha:sub(1, 7)
  end

  T("short_sha nil → ?", short_sha(nil) == "?")
  T("short_sha vazio → ?", short_sha("") == "?")
  T("short_sha 40 chars → 7", short_sha("279337a28edb8a09393701e556ade743f25f2946") == "279337a")
  T("short_sha 7 chars → idêntico", short_sha("abc1234") == "abc1234")
  T("short_sha 3 chars → idêntico (sem pad)", short_sha("ab") == "ab")

  local function trim_version(raw)
    return (raw or ""):match("^%s*(.-)%s*$") or "?"
  end

  T("trim_version com espaços e newline", trim_version("  0.9.1\n") == "0.9.1")
  T("trim_version vazio → vazio", trim_version("") == "")
  T("trim_version só whitespace → vazio", trim_version("   \n\t  ") == "")
  T("trim_version sem espaços", trim_version("1.2.3") == "1.2.3")

  -- Contrato de quoting BASE_Q: 'path' com aspas simples escapadas
  local function quote_base(base)
    return "'" .. base:gsub("'", "'\\''") .. "'"
  end

  T("BASE_Q path simples", quote_base("/home/u/TermAI") == "'/home/u/TermAI'")
  T("BASE_Q com espaço", quote_base("/home/my user/TermAI") == "'/home/my user/TermAI'")
  T("BASE_Q com aspas simples", quote_base("/home/o'brien/TermAI") == "'/home/o'\\''brien/TermAI'")
end

return M
