-- tools/editor/diff_builder.lua — Gera preview textual (old/new) das edições.
-- v2: Adiciona contexto (2 linhas antes/depois), numeração de linhas e cálculo de métricas.
local M = {}

local MAX_DIFF_LINES = 30

local function split_lines(content)
  local lines, p = {}, 1
  while p <= #content do
    local q = content:find("\n", p, true) or (#content + 1)
    lines[#lines + 1] = content:sub(p, q - 1)
    p = q + 1
  end
  return lines
end

-- before_content: conteúdo do arquivo ANTES da edição (string)
-- patches: array de {old=, new=} ou {type="lines", ls=, le=, new=}
-- Retorna string do diff formatado, total_adicionadas, total_removidas
function M.build(before_content, patches)
  if not before_content or not patches or #patches == 0 then return nil, 0, 0 end

  local file_lines = split_lines(before_content)
  local parts = {}
  local added_total = 0
  local removed_total = 0

  for _, patch in ipairs(patches) do
    local old, new, start_ln, end_ln
    if patch.old then
      old = patch.old
      new = patch.new or ""
      local pos = before_content:find(old, 1, true)
      if pos then
        local count = 1
        for _ in before_content:sub(1, pos - 1):gmatch("\n") do
          count = count + 1
        end
        start_ln = count
      else
        start_ln = 1
      end
      local old_lns = {}
      for ln in (old .. "\n"):gmatch("([^\n]*)\n") do
        old_lns[#old_lns + 1] = ln
      end
      end_ln = start_ln + #old_lns - 1
    elseif patch.type == "lines" and file_lines and patch.ls and patch.le then
      start_ln = patch.ls
      end_ln = math.min(patch.le, #file_lines)
      local seg = {}
      for j = start_ln, end_ln do
        seg[#seg + 1] = file_lines[j]
      end
      old = table.concat(seg, "\n")
      new = patch.new or ""
    end

    if old then
      local old_lns = {}
      for ln in (old .. "\n"):gmatch("([^\n]*)\n") do
        old_lns[#old_lns + 1] = ln
      end
      removed_total = removed_total + #old_lns

      local new_lns = {}
      if new ~= "" then
        for ln in (new .. "\n"):gmatch("([^\n]*)\n") do
          new_lns[#new_lns + 1] = ln
        end
        added_total = added_total + #new_lns
      end

      -- 1. Contexto Antes (até 2 linhas)
      local ctx_start = math.max(1, start_ln - 2)
      for j = ctx_start, start_ln - 1 do
        parts[#parts + 1] = string.format("%3d   | %s", j, file_lines[j] or "")
      end

      -- 2. Linhas Removidas (-)
      for j, ln in ipairs(old_lns) do
        local cur_ln = start_ln + j - 1
        parts[#parts + 1] = string.format("%3d - | %s", cur_ln, ln)
      end

      -- 3. Linhas Adicionadas (+)
      for j, ln in ipairs(new_lns) do
        parts[#parts + 1] = string.format("%3d + | %s", start_ln + j - 1, ln)
      end

      -- 4. Contexto Depois (até 2 linhas)
      local ctx_end = math.min(#file_lines, end_ln + 2)
      for j = end_ln + 1, ctx_end do
        parts[#parts + 1] = string.format("%3d   | %s", j, file_lines[j] or "")
      end
    end
  end

  if #parts == 0 then return nil, 0, 0 end
  local out = {}
  for i = 1, math.min(#parts, MAX_DIFF_LINES) do out[#out + 1] = parts[i] end
  if #parts > MAX_DIFF_LINES then
    out[#out + 1] = "... (" .. (#parts - MAX_DIFF_LINES) .. " linhas omitidas)"
  end
  return table.concat(out, "\n"), added_total, removed_total
end

return M
