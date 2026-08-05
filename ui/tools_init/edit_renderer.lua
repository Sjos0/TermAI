-- ui/tools_init/edit_renderer.lua — Renderizador especializado de diffs estruturados (Aider-style).
local core = require("ui.core")
local c    = core.c

local M = {}

-- ok já vem processado (actual_ok do executor), sem necessidade de revalidar
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
  if added and removed then
    local summary = string.format("Adicionadas %d linha(s), removida(s) %d linha(s)", added, removed)
    local text_color = (added == 0 and removed == 0) and c.red or c.cyan
    io.write(c.gray .. prefix .. text_color .. "└ " .. summary .. c.reset .. "\n")
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
  while idx <= #lines do
    if idx ~= 1 and idx ~= metrics_idx then
      if show_line[idx] then
        local ln = lines[idx]
        local ln_str, marker, content = ln:match("^%s*(%d+)%s*([%-%+ ]?)%s*|%s*(.*)$")

        if ln:match("^%.%.%.") then
          io.write(c.gray .. prefix .. c.dim .. ln .. c.reset .. "\n")
        elseif ln_str and marker and content then
          local formatted = string.format("%4s %s  %s", ln_str, marker ~= " " and marker or " ", content)

          local max_w = tw - 12
          if #formatted > max_w then
            formatted = formatted:sub(1, max_w - 3) .. "..."
          end

          if marker == "-" then
            io.write(c.gray .. prefix .. c.red .. formatted .. c.reset .. "\n")
          elseif marker == "+" then
            io.write(c.gray .. prefix .. c.green .. formatted .. c.reset .. "\n")
          else
            io.write(c.gray .. prefix .. c.gray .. formatted .. c.reset .. "\n")
          end
        else
          io.write(c.gray .. prefix .. c.white .. ln:sub(1, tw - 8) .. c.reset .. "\n")
        end
        idx = idx + 1
      else
        local hidden_count = 0
        while idx <= #lines and not show_line[idx] and idx ~= metrics_idx do
          hidden_count = hidden_count + 1
          idx = idx + 1
        end
        if hidden_count > 0 then
          io.write(c.gray .. prefix .. c.dim .. "... (" .. hidden_count .. " linhas ocultas) ..." .. c.reset .. "\n")
        end
      end
    else
      idx = idx + 1
    end
  end

  -- 4. Conclusão Extra de Rodapé
  if ok then
    io.write(c.gray .. " └─ " .. c.green .. "Substituição concluída ✓" .. c.reset .. "\n")
  else
    io.write(c.gray .. " └─ " .. c.red .. "Substituição falha ❌" .. c.reset .. "\n")
  end
end

return M
