-- lib/result.lua — Ponto único de detecção do resultado de ferramenta.
-- Issue #343 (passo 2 da opção D — expandir-contrair — da #325).
--
-- O prefixo de resultado é PROTOCOLO entre as tools e o harness: quem consome lê o
-- prefixo para decidir se a ferramenta falhou. Enquanto os produtores migram de
-- símbolo para palavra (lotes 2 a 4 do #325), cada consumidor precisa aceitar os
-- DOIS formatos — e a leitura do prefixo precisa viver num lugar só:
--
--   falha ............... símbolo "❌"          | palavra "[FAIL]"
--   vazio ............... símbolo "📭"          | palavra "[EMPTY]"
--   busca sem resultado . símbolo "🔍 Nenhum"   | palavra "[SEARCH] Nenhum"
--
-- Alcançável pelos dois mundos com o mesmo require("lib.result"):
--   runtime — main.lua:5 põe BASE/?.lua no package.path;
--   specs   — rodando da raiz do repositório, ./?.lua do default do Lua.
-- (tests/lib_result_spec.lua prova isso.)
--
-- Nada aqui produz texto: os PRODUTORES não mudam nesta fase (o símbolo só sai no D6).
local M = {}

local FALHA_SIMBOLO,  FALHA_PALAVRA  = "❌", "[FAIL]"
local VAZIO_SIMBOLO,  VAZIO_PALAVRA  = "📭", "[EMPTY]"
local BUSCA_SIMBOLO,  BUSCA_PALAVRA  = "🔍 Nenhum", "[SEARCH] Nenhum"

-- Comparação por bytes: "❌" e "📭" são multibyte, e o prefixo é sempre no início.
local function tem_prefixo(s, prefixo)
  return type(s) == "string" and s:sub(1, #prefixo) == prefixo
end

--- A ferramenta falhou? (símbolo antigo ou palavra nova)
function M.e_falha(s)
  return tem_prefixo(s, FALHA_SIMBOLO) or tem_prefixo(s, FALHA_PALAVRA)
end

--- A ferramenta devolveu vazio? (símbolo antigo ou palavra nova)
function M.e_vazio(s)
  return tem_prefixo(s, VAZIO_SIMBOLO) or tem_prefixo(s, VAZIO_PALAVRA)
end

--- A busca terminou sem resultado? (símbolo antigo ou palavra nova)
-- Procurar em qualquer posição, como tools/web.lua já fazia.
-- @param detalhe string|nil Palavra seguinte exigida (ex.: "resultado"). Sem ela,
--        vale a assinatura larga da família ("Nenhum").
function M.e_busca_vazia(s, detalhe)
  if type(s) ~= "string" then return false end
  local cauda = detalhe and (" " .. detalhe) or ""
  return s:find(BUSCA_SIMBOLO .. cauda, 1, true) ~= nil
      or s:find(BUSCA_PALAVRA .. cauda, 1, true) ~= nil
end

--- Não serve para consumir nem injetar: falhou, veio vazio ou a busca não achou nada.
function M.e_nao_util(s)
  return M.e_falha(s) or M.e_vazio(s) or M.e_busca_vazia(s)
end

--- Não falhou. Substituto de `not s:match("^❌")`.
-- Fail-closed: entrada não-string nunca é sucesso (não inventa sucesso onde não há
-- resultado algum).
function M.sucesso(s)
  if type(s) ~= "string" then return false end
  return not M.e_falha(s)
end

--- Corpo da mensagem sem o prefixo de falha (antigo ou novo).
-- Sem prefixo reconhecido, devolve a própria string, intacta.
function M.mensagem(s)
  if type(s) ~= "string" then return s end
  local corpo = s:match("^❌%s*(.-)%s*$")
  if corpo ~= nil then return corpo end
  corpo = s:match("^%[FAIL%]%s*(.-)%s*$")
  if corpo ~= nil then return corpo end
  return s
end

return M
