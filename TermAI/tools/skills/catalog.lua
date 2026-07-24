-- tools/skills/catalog.lua — Gerador de Catalogo de Skills (XML).
-- Recebe lista de skills do discovery e gera bloco XML para o system prompt.
-- Funcao pura: sem efeitos colaterais, sem acesso a disco.
--
-- Modelo: gitlawb/mimo-v2.5-pro
-- Primeira feature planejada diretamente do Terminal (Termux/Android)
-- Autor: Samuel Rosa + Ameno | Data: 2026-05-25

local M = {}

-- ── get_imperative_instruction ──────────────────────────────────────────────
-- Retorna o texto imperativo injetado junto com o catalogo.
-- Instrui o agente a ser sensivel as skills e usa-las quando apropriado.
function M.get_imperative_instruction()
  return "Voce POSSUI Skills especializadas listadas acima. "
    .. "Quando uma tarefa do usuario se alinha com a descricao de uma Skill, "
    .. "voce DEVE chamar a ferramenta 'skill' para carrega-la "
    .. "ANTES de tentar resolver o problema sozinho. "
    .. "Skills contem instrucoes especializadas que melhoram "
    .. "drasticamente a qualidade da sua resposta."
end

-- ── build ───────────────────────────────────────────────────────────────────
-- Recebe lista de skills (tabela com {name, description, path, base_dir}).
-- Gera XML no formato <available_skills>...</available_skills>.
-- Se lista estiver vazia, retorna string vazia (sem catalogo).
function M.build(skills_list)
  if not skills_list or #skills_list == 0 then
    return ""
  end

  local parts = {}
  parts[#parts + 1] = "<available_skills>"

  for _, skill in ipairs(skills_list) do
    parts[#parts + 1] = "  <skill>"
    parts[#parts + 1] = "    <name>" .. skill.name .. "</name>"
    parts[#parts + 1] = "    <description>" .. skill.description .. "</description>"
    parts[#parts + 1] = "    <location>" .. skill.path .. "</location>"
    parts[#parts + 1] = "  </skill>"
  end

  parts[#parts + 1] = "</available_skills>"
  parts[#parts + 1] = ""
  parts[#parts + 1] = M.get_imperative_instruction()

  return table.concat(parts, "\n")
end

return M
