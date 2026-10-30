local core = require("ui.core")
local card = require("ui.card")
local c    = core.c

local M = {}

function M.render_edit_body(lines, ok, tw)
  local added, removed = nil, nil
  local metrics_idx = nil

  -- 1. Varredura de busca de métricas na string
  for idx, ln in ipairs(lines) do
    local a, r = ln:match("^METRICS:%s*added=(%d+),%s*removed=(%d+)")
    if a and r then
      added, removed = tonumber(a), tonumber(r)
      metrics_idx = idx
      break
    end
  end

  -- 2. Imprime resumo de alterações no topo da box
  local prefix = " │ "
  -- Linha do card com fundo c.bg (#176 P1). Texto puro + cor; uma única sequência de reset no fim.
  local function row(p, tc, text)
    io.write(card.bg_row(c.bg, c.gray, p, tc, text, tw) .. "\n")
  end
  if added and removed then
    local summary = string.format("Adicionadas %d linha(s), removida(s) %d linha(s)", added, removed)
    local text_color = (added == 0 and removed == 0) and c.red or c.cyan
    row(prefix, text_color, "└ " .. card.cut(summary, tw - 8))
  end

  -- 3. Imprime linhas de diff formatadas
  local N = 3 -- lines of context
  local show_line = {}
  local is_diff_line = {}
  local is_changed_line = {}

  for idx, ln in ipairs(lines) do
    show_line[idx] = true
    if idx ~= 1 and idx ~= metrics_idx then
      local ln_str, marker, content = ln:match("^%s*(%d+)%s*([%-%+ ]?)%s*|%s*(.*)$")
      if ln_str and marker and content then
        is_diff_line[idx] = true
        if marker == "+" or marker == "-" then
          is_changed_line[idx] = true
        end
        show_line[idx] = false
      end
    end
  end

  local has_any_change = false
  for idx, _ in ipairs(lines) do
    if is_changed_line[idx] then
      has_any_change = true
      break
    end
  end

  if has_any_change then
    for idx = 1, #lines do
      if is_diff_line[idx] then
        if is_changed_line[idx] then
          show_line[idx] = true
        else
          local near = false
          for j = math.max(1, idx - N), math.min(#lines, idx + N) do
            if is_changed_line[j] then
              near = true
              break
            end
          end
          if near then
            show_line[idx] = true
          end
        end
      end
    end
  else
    for idx = 1, #lines do
      if is_diff_line[idx] then
        show_line[idx] = true
      end
    end
  end

  local idx = 1
  local printed = 0
  while idx <= #lines do
    if idx ~= 1 and idx ~= metrics_idx then
      if show_line[idx] then
        -- Corpo recolhido (regra de card): depois de MAX_BODY linhas, mostra quantas faltam e para.
        if printed >= card.MAX_BODY then
          local left = 0
          for j = idx, #lines do
            if j ~= metrics_idx and show_line[j] then left = left + 1 end
          end
          if left > 0 then
            row(prefix, c.dim, "... (" .. left .. " linhas)")
          end
          break
        end
        printed = printed + 1
        local ln = lines[idx]
        local ln_str, marker, content = ln:match("^%s*(%d+)%s*([%-%+ ]?)%s*|%s*(.*)$")

        if ln:match("^%.%.%.") then
          row(prefix, c.dim, ln)
        elseif ln_str and marker and content then
          local formatted = string.format("%4s %s  %s", ln_str, marker ~= " " and marker or " ", content)

          local max_w = tw - 12
          formatted = card.cut(formatted, max_w)

          if marker == "-" then
            row(prefix, c.red, formatted)
          elseif marker == "+" then
            row(prefix, c.green, formatted)
          else
            row(prefix, c.gray, formatted)
          end
        else
          row(prefix, c.white, card.cut(ln, tw - 8))
        end
        idx = idx + 1
      else
        local hidden_count = 0
        while idx <= #lines and not show_line[idx] and idx ~= metrics_idx do
          hidden_count = hidden_count + 1
          idx = idx + 1
        end
        if hidden_count > 0 then
          row(prefix, c.dim, "... (" .. hidden_count .. " linhas ocultas) ...")
        end
      end
    else
      idx = idx + 1
    end
  end

  -- 4. Conclusão Extra de Rodapé
  if ok then
    row(" └─ ", c.green, "Substituição concluída ✓")
  else
    row(" └─ ", c.red, "Substituição falha ❌")
  end
end

return M
