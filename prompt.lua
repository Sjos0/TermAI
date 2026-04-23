local M = {}

local function ler(p, d)
  local f = io.open(p, "r")
  if not f then return d or "" end
  local c = f:read("*a")
  f:close()
  return c
end

function M.build(workspace, tools)
  local sys = ler(workspace.."/SOUL.md",     "Você é o TermAI.")
           .."\n\n"..ler(workspace.."/IDENTITY.md",  "")
           .."\n\n"..ler(workspace.."/STRUCTURE.md", "")
           .."\n\n"..ler(workspace.."/AGENTS.md",    "")
           .."\n\n"..tools.get_docs()
           .."\n\n### MEMÓRIA DE LONGO PRAZO\n"..ler(workspace.."/MEMORY.md", "")
           .."\n\n"..ler(workspace.."/USER.md", "")

  sys = sys .. [[

## INSTRUÇÕES OBRIGATÓRIAS DE FERRAMENTAS (XML)
Para qualquer ação no sistema, use OBRIGATORIAMENTE o formato XML abaixo. A ferramenta será executada invisivelmente.

Formato de Execução:
<tool>
  <name>nome_da_ferramenta</name>
  <arg>argumento_aqui</arg>
</tool>

Regras de Segurança Críticas:
1. O sistema IGNORA ferramentas dentro de blocos de código markdown (```). Use blocos de código SOMENTE para mostrar exemplos ou citar trechos de arquivos lidos.
2. Múltiplas ferramentas na mesma resposta executam em lote.
3. O resultado da ferramenta chegará para você no formato <tool_result>.
4. Nunca use o antigo formato [CMD:] ou [TOOL:].
]]

  return sys
end

return M
