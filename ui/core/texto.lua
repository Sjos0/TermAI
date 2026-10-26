-- ui/core/texto.lua — helpers de texto e largura visual (strip, wlen, wrap, render, reasoning).
return function(core)
  local renderer = require("renderer")
  local utf8 = require("utf8")

  -- ── Helpers de texto ───────────────────────────────────────────────────────

  -- Optimization (Bolt): Fast early return for strings without ANSI escape sequences.
  -- 99.9% of strings in CLI output are plain text — skip expensive gsub entirely.
  function core.strip(s)
    if not s:find("\27", 1, true) then return s end
    return (s:gsub("\27%[[0-9;]*m", ""))
  end

  function core.cp_width(cp)
    return ((cp >= 0x1100 and cp <= 0x115f) or cp >= 0x2e80 or cp > 0x1f000) and 2 or 1
  end

  function core.cp_byte_len(cp)
    if cp <= 0x7F then return 1
    elseif cp <= 0x7FF then return 2
    elseif cp <= 0xFFFF then return 3
    else return 4 end
  end

  local function get_utf8_len(s)
    local n = 0
    for _, cp in utf8.codes(s) do
      n = n + core.cp_width(cp)
    end
    return n
  end

  function core.wlen(s)
    s = core.strip(s or "")
    -- ASCII fast-path: sem custo de closure ou pcall
    if not s:find("[^\1-\127]") then
      return #s
    end
    -- Static pcall: sem alocar novas closures na heap
    local ok, n = pcall(get_utf8_len, s)
    if ok then return n end
    return #s
  end

  function core.wrap_para(para, w)
    local out, line = {}, ""
    for word in (para .. " "):gmatch("(%S+)%s*") do
      local candidate = line == "" and word or line .. " " .. word
      if core.wlen(candidate) > w then
        if line ~= "" then out[#out + 1] = line end
        line = word
      else
        line = candidate
      end
    end
    if line ~= "" then out[#out + 1] = line end
    if #out == 0 then out[#out + 1] = "" end
    return out
  end

  -- ── Renderização ───────────────────────────────────────────────────────────

  function core.render_dim(text)
    local rendered = renderer.render(text)
    rendered = rendered:gsub("\27%[0m", "\27[0m" .. core.c.dim .. core.c.gray)
    return rendered
  end

  function core.render(text)
    return renderer.render(text)
  end

  function core.print_reasoning_line(text, w)
    local lines = core.wrap_para(text, w)
    for _, ln in ipairs(lines) do
      io.write(core.c.dim .. core.c.gray .. " │ " .. ln .. "\27[K" .. core.c.reset .. "\n")
    end
  end

  -- ── Contagem e truncamento de linhas ───────────────────────────────────────

  function core.truncate_reasoning(text, max_content_lines, term_width)
    local content_lines = 0
    local col = 3
    local byte_pos = 0
    for _, cp in utf8.codes(text) do
      byte_pos = byte_pos + core.cp_byte_len(cp)
      if cp == 10 then
        content_lines = content_lines + 1
        col = 3
        if content_lines >= max_content_lines then
          return text:sub(1, byte_pos), col
        end
      else
        local cw = core.cp_width(cp)
        col = col + cw
        if col > term_width then
          content_lines = content_lines + 1
          col = cw
          if content_lines >= max_content_lines then
            return text:sub(1, byte_pos), col
          end
        end
      end
    end
    return text, col
  end

  function core.count_lines_in(text, start_col, term_width)
    local lines = 0
    local col = start_col
    for _, cp in utf8.codes(text) do
      if cp == 10 then
        lines = lines + 1
        col = 3
      else
        local cw = core.cp_width(cp)
        col = col + cw
        if col > term_width then
          lines = lines + 1
          col = cw
        end
      end
    end
    return lines, col
  end

end
