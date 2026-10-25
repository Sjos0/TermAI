-- tests/doc_gap_surfaces_spec/02_parte.lua — parte de doc_gap_surfaces_spec.lua (ver fachada).
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

  local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a") or ""
    f:close()
    return s
  end


  -- ─────────────────────────────────────────────────────────────

  local main_src = read_file("main.lua") or read_file("./main.lua")
  if main_src then
    for _, key in ipairs({ "tui", "status", "models", "restart", "config", "update", "npx", "skills" }) do
      T("main.lua mapa tem chave " .. key,
        main_src:find(key .. "%s*=") ~= nil)
    end
    T("banner menciona TermAI skills",
      main_src:find("TermAI skills", 1, true) ~= nil)
    T("banner menciona TermAI npx",
      main_src:find("TermAI npx", 1, true) ~= nil)
    T("banner menciona TermAI restart",
      main_src:find("TermAI restart", 1, true) ~= nil)
  else
    T("main.lua legível no cwd", false, "rode da raiz do clone")
  end

  -- ─────────────────────────────────────────────────────────────
  sec("help.lua CLI lista subcomandos reais (#65 #54)")
  -- ─────────────────────────────────────────────────────────────

  local help_src = read_file("commands/help.lua") or read_file("./commands/help.lua")
  if help_src then
    for _, word in ipairs({ "config", "skills", "npx", "restart", "update", "tui", "status", "models" }) do
      T("help.lua menciona " .. word, help_src:find(word, 1, true) ~= nil)
    end
  else
    T("help.lua legível no cwd", false, "rode da raiz do clone")
  end

  -- ─────────────────────────────────────────────────────────────
end

return M
