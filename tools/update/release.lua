-- tools/update/release.lua — Regras puras do update por release (sem git e sem rede).
-- Usado por commands/update.lua. Testes: tests/update_release_spec.lua.
local M = {}

M.REPO = "Sjos0/TermAI"

-- Lê tag_name do JSON de /repos/<repo>/releases/latest. Só aceita tags seguras (vX.Y.Z).
function M.parse_tag(body)
  if type(body) ~= "string" then return nil end
  local tag = body:match('"tag_name"%s*:%s*"([^"]+)"')
  if not tag or not tag:match("^v[%w%._%-]+$") then return nil end
  return tag
end

-- Ref que o update deve aplicar: a release (padrão) ou a ponta da main (--main).
function M.ref_for(mode, tag)
  if mode == "main" then return "origin/main" end
  return tag
end

local function prev_path(home) return home .. "/.TermAI/update_previous" end

-- Guarda o commit de antes do update, para --rollback.
function M.save_previous(home, sha)
  local f = io.open(prev_path(home), "w")
  if not f then return false end
  f:write(tostring(sha), "\n")
  f:close()
  return true
end

-- Commit guardado pelo último update (nil se não houver ou se for inválido).
function M.read_previous(home)
  local f = io.open(prev_path(home), "r")
  if not f then return nil end
  local sha = (f:read("*l") or ""):match("^%x+$")
  f:close()
  return sha
end

return M
