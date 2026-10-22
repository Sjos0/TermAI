-- tools/subagents/redact.lua — Mascara segredos antes de exibir ou gravar texto de subagente.
-- Um subagente pode rodar comandos com tokens no cabeçalho (ex.: curl -H "Authorization: token ...").
-- Este módulo é o único ponto de limpeza: events.append e a TUI passam por aqui.
local M = {}

function M.clean(s)
  s = tostring(s or "")
  s = s:gsub("Authorization:%s*[^%s\"']+%s+[^%s\"']+", "Authorization: ***")
  s = s:gsub("Authorization:%s*[^%s\"']+", "Authorization: ***")
  s = s:gsub("Bearer%s+[^%s\"']+", "Bearer ***")
  s = s:gsub("ghp_[%w]+", "ghp_***")
  s = s:gsub("github_pat_[%w_]+", "github_pat_***")
  s = s:gsub("sk%-[%w_%-]+", "sk-***")
  return s
end

return M
