-- tools/editor/edit_engine/multi_edit.lua — Orquestracao de multiplas edicoes.
-- Conteudo original congelado, ordem reversa, overlap, validacao previa.
-- Copiado do OpenClaw: multi-edit com atomicidade.
-- Autor: Ameno | Data: 2026-05-30 | Refatoracao editor-lua
-- Fix Bug#15: patches "lines" usam posicao direta; matcher/validator intocados.

local norm = require("tools.editor.normalizer")
local val = require("tools.editor.validator")
local matcher = require("tools.editor.edit_engine.matcher")
local recovery = require("tools.editor.edit_engine.recovery")

local M = {}

-- Aplica multiplas edicoes com fuzzy match, conteudo original congelado,
-- ordem reversa, e validacao de sintaxe previa.
-- read_file_fn e write_file_fn sao injetados pelo editor.lua.
function M.replace_multi(path, patches, read_file_fn, write_file_fn)
  local content, err = read_file_fn(path)
  if not content then return false, err end

  -- Preservar formato original para restauracao
  local original_ending = norm.detect_line_ending(content)
  local _, had_bom = norm.strip_bom(content)

  -- Fase 1: Localizar TODAS as edicoes no conteudo ORIGINAL (congelado)
  local located = {}
  local any_fuzzy = false

  for i, patch in ipairs(patches) do
    local is_lines = patch.type == "lines"

    if is_lines then
      -- Fase 0 + localizar: resolver range e calcular posicao de byte diretamente.
      -- Para patches "lines" nao usamos o matcher — a posicao ja e conhecida pelo
      -- range, o que elimina o problema de old_text vazio (linha em branco) e
      -- evita falsos erros de unicidade.
      local lines_tmp, p = {}, 1
      while p <= #content do
        local q = content:find("\n", p, true) or (#content + 1)
        lines_tmp[#lines_tmp + 1] = content:sub(p, q - 1)
        p = q + 1
      end
      if patch.ls < 1 or patch.le > #lines_tmp or patch.ls > patch.le then
        return false, string.format(
          "Falha no patch %d/%d: range L%d-%d invalido (arquivo tem %d linhas)",
          i, #patches, patch.ls, patch.le, #lines_tmp
        )
      end
      -- Montar old_text e calcular byte offset do inicio da linha ls
      local seg = {}
      for j = patch.ls, patch.le do seg[#seg + 1] = lines_tmp[j] end
      local old_text = table.concat(seg, "\n")

      local byte_pos = 1
      for ln = 1, patch.ls - 1 do
        byte_pos = byte_pos + #lines_tmp[ln] + 1  -- +1 para o \n separador
      end

      located[#located + 1] = {
        index    = i,
        pos      = byte_pos,
        len      = #old_text,
        patch    = { old = old_text, new = patch.new },
        fuzzy    = false,
        is_lines = true,
      }

    else
      -- Busca normal por conteudo (search-and-replace)
      local ok, msg, updated, fuzzy = matcher.apply_one(content, patch.old, patch.new, i)
      if not ok then
        local prefix = "Falha no patch " .. i .. "/" .. #patches .. ": "
        if msg:match("encontr") then
          if recovery.detect_already_applied(content, patch.old, patch.new) then
            return true, "Edicao ja aplicada [" .. i .. "/" .. #patches .. "]"
          end
          local prev = recovery.recovery_mismatch(path, read_file_fn)
          if prev then
            return false, prefix .. msg .. prev
          end
        end
        return false, prefix .. msg
      end
      if not (msg and msg:match("ja aplicada")) then
        local search_text = patch.old
        if fuzzy then
          search_text = select(1, norm.normalize_all(patch.old))
        end
        local pos = content:find(search_text, 1, true)
        if not pos then
          return false, "Falha no patch " .. i .. "/" .. #patches .. ": posicao nao encontrada"
        end
        located[#located + 1] = {
          index    = i,
          pos      = pos,
          len      = #search_text,
          patch    = patch,
          fuzzy    = fuzzy,
          is_lines = false,
        }
        if fuzzy then any_fuzzy = true end
      end
    end
  end

  -- Fase 2: Ordenar por posicao (crescente)
  table.sort(located, function(a, b) return a.pos < b.pos end)

  -- Fase 3: Verificar OVERLAP entre edicoes adjacentes
  for i = 2, #located do
    local prev = located[i - 1]
    local curr = located[i]
    if prev.pos + prev.len > curr.pos then
      return false, "Edicoes " .. prev.index .. " e " .. curr.index
        .. " se sobrepoem"
    end
  end

    -- Fase 4: Pulada (Decisão [D-026]) - A Fase 7 já garante a integridade
    -- total do arquivo compilado pós-edição com rollback automático,
    -- eliminando a necessidade de pré-validação estrita do fragmento standalone.

  -- Fase 5: Aplicar em ORDEM REVERSA (fim -> inicio)
  local current = content
  for i = #located, 1, -1 do
    local loc = located[i]
    local old_text = loc.patch.old
    local new_text = loc.patch.new
    if loc.fuzzy then
      old_text = select(1, norm.normalize_all(old_text))
      new_text = select(1, norm.normalize_all(new_text))
    end
    current = current:sub(1, loc.pos - 1)
      .. new_text
      .. current:sub(loc.pos + loc.len)
  end

  -- Fase 6: Restaurar formato original se fuzzy foi ativado
  if any_fuzzy then
    current = norm.restore_format(current, had_bom, original_ending)
  end

  -- Fase 7: Escrever e validar
  local wok, werr = write_file_fn(path, current)
  if not wok then return false, werr end

  local valid, lint_err = val.validate_lua(path)
  if not valid then
    write_file_fn(path, content)
    return false, "Sintaxe invalida apos edicao (revertido):\n" .. lint_err
      .. "\n\nSugestao: verifique se o trecho novo nao quebrou parenteses, chaves ou aspas."
  end

  local suffix = #patches > 1 and (" (" .. #patches .. " patches aplicados)") or ""
  return true, "Substituicao aplicada" .. suffix
end

return M
