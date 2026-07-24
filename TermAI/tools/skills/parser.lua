-- tools/skills/parser.lua — Parser de SKILL.md (YAML frontmatter + body).
-- Separa o frontmatter YAML do corpo markdown de um arquivo SKILL.md.
-- Nao depende de nenhuma lib externa — regex puro, compativel com Lua 5.4.
--
-- Modelo: gitlawb/mimo-v2.5-pro
-- Primeira feature planejada diretamente do Terminal (Termux/Android)
-- Autor: Samuel Rosa + Ameno | Data: 2026-05-25

local M = {}

-- ── parse_yaml_lines ────────────────────────────────────────────────────────
-- Parse simples de YAML linha a linha (key: value).
-- Suporta: strings, aspas, listas simples [item1, item2], multiline ">".
-- Ignora linhas de comentario (#).
-- Retorna tabela {key = value, ...}.
local function parse_yaml_lines(yaml_text)
  local result = {}
  local current_key = nil
  local multiline_buf = nil

  for line in (yaml_text .. "\n"):gmatch("([^\n]*)\n") do
    -- Ignorar linhas vazias e comentarios
    if line:match("^%s*$") or line:match("^%s*#") then
      -- nada

    -- Multiline: linha que comeca com espaco (continuacao do valor anterior)
    elseif current_key and multiline_buf and line:match("^%s+") then
      local value = line:match("^%s*(.-)%s*$")
      if value ~= "" then
        multiline_buf[#multiline_buf + 1] = value
      end

    -- Chave: valor (linha normal)
    else
      -- Salvar multiline pendente
      if current_key and multiline_buf then
        result[current_key] = table.concat(multiline_buf, " ")
        multiline_buf = nil
        current_key = nil
      end

      local key, value = line:match("^%s*(%S+)%s*:%s*(.-)%s*$")
      if key then
        -- Comentar: valor vazio pode iniciar multiline
        if value == ">" or value == "|-" or value == "|" then
          current_key = key
          multiline_buf = {}
        -- Lista simples: [item1, item2]
        elseif value:match("^%[.-%]$") then
          local list = {}
          for item in value:sub(2, -2):gmatch("[^,]+") do
            list[#list + 1] = item:match("^%s*(.-)%s*$")
          end
          result[key] = list
        -- Valor entre aspas duplas
        elseif value:match('^".-"$') then
          result[key] = value:sub(2, -2)
        -- Valor entre aspas simples
        elseif value:match("^'.-'$") then
          result[key] = value:sub(2, -2)
        -- Valor comum
        elseif value ~= "" then
          result[key] = value
        -- Valor vazio (pode ser inicio de multiline no proximo turno)
        else
          current_key = key
          multiline_buf = {}
        end
      end
    end
  end

  -- Salvar multiline final pendente
  if current_key and multiline_buf then
    result[current_key] = table.concat(multiline_buf, " ")
  end

  return result
end

-- ── parse ───────────────────────────────────────────────────────────────────
-- Recebe conteudo completo de um arquivo SKILL.md (string).
-- Retorna {name, description, metadata, body} ou nil, erro.
function M.parse(content)
  if not content or content == "" then
    return nil, "Arquivo vazio"
  end

  -- Normalizar quebras de linha
  content = content:gsub("\r\n", "\n"):gsub("\r", "\n")

  -- Encontrar primeiro --- (abertura do frontmatter)
  local fm_start = content:find("^%-%-%-%s*\n", 1)
  if not fm_start then
    return nil, "Frontmatter nao encontrado (esperado --- no inicio)"
  end

  -- Encontrar segundo --- (fechamento do frontmatter)
  local fm_end = content:find("\n%-%-%-%s*\n", fm_start + 3)
  if not fm_end then
    return nil, "Frontmatter nao fechado (esperado --- de fechamento)"
  end

  -- Extrair YAML (entre os dois ---)
  local yaml_text = content:sub(fm_start + 3, fm_end - 1)

  -- Extrair body (tudo depois do segundo ---)
  local body = content:sub(fm_end + 4)
  body = body:match("^%s*(.-)%s*$") or ""

  -- Parsear YAML
  local yaml = parse_yaml_lines(yaml_text)

  -- Validar campos obrigatorios
  local name = yaml.name
  local description = yaml.description

  if not name or name == "" then
    return nil, "Campo 'name' obrigatorio ausente no frontmatter"
  end
  if not description or description == "" then
    return nil, "Campo 'description' obrigatorio ausente no frontmatter"
  end

  -- Metadata e opcional: tudo que nao e name nem description
  local metadata = {}
  for k, v in pairs(yaml) do
    if k ~= "name" and k ~= "description" then
      metadata[k] = v
    end
  end

  return {
    name        = name,
    description = description,
    metadata    = metadata,
    body        = body,
  }, nil
end

return M
