-- tests/exec_tela_emulador_spec.lua — #243: prova ponta a ponta Exec + caracteres largos.
-- Emulador de terminal INDEPENDENTE: não importa ui/largura.lua nem ui/card.lua para medir.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

do
  local real_getenv = os.getenv
  local tmp = real_getenv("TMPDIR") or "/tmp"
  os.getenv = function(k) if k == "TMPDIR" then return tmp end return real_getenv(k) end
end

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

-- ── Tabela de largura PRÓPRIA do teste (não usar produção) ──────────────────
local function ref_cp_width(cp, prev)
  if cp == 0xFE0F then return 0 end -- VS16
  if cp == 0x200D then return 0 end -- ZWJ
  if cp >= 0x1F300 and cp <= 0x1FAFF then return 2 end -- emoji plane
  if cp == 0x2705 or cp == 0x274C or cp == 0x26A0 then return 2 end
  if cp == 0x1F525 then return 2 end
  -- CJK ranges (simplified)
  if (cp >= 0x3000 and cp <= 0x9FFF)
    or (cp >= 0xF900 and cp <= 0xFAFF)
    or (cp >= 0xFF00 and cp <= 0xFFEF) then
    return 2
  end
  if cp == 0x09 then return nil end -- tab special
  if cp < 32 then return 0 end
  return 1
end

local function ref_width(s, col_start)
  col_start = col_start or 0
  local n, prev = col_start, nil
  local ok = pcall(function()
    for _, cp in utf8.codes(s) do
      if cp == 0x09 then
        n = n + (8 - (n % 8))
      else
        n = n + (ref_cp_width(cp, prev) or 1)
      end
      prev = cp
    end
  end)
  if not ok then return #s end
  return n - col_start
end

-- ── Emulador mínimo ─────────────────────────────────────────────────────────
local function new_term(tw, th)
  th = th or 40
  local lines = {}
  for i = 1, th do lines[i] = "" end
  local row, col = 1, 0 -- 1-based row, 0-based col
  local pending_wrap = false

  local function ensure_row()
    while #lines < row do lines[#lines + 1] = "" end
  end

  local function set_cell_append(ch, w)
    ensure_row()
    -- pad with spaces up to col
    local cur = lines[row]
    local visual = ref_width(cur)
    if visual < col then
      cur = cur .. string.rep(" ", col - visual)
    end
    lines[row] = cur .. ch
    col = col + w
  end

  local function put_char(ch, w)
    if pending_wrap then
      row = row + 1
      col = 0
      pending_wrap = false
      ensure_row()
    end
    if col + w > tw then
      -- wrap
      row = row + 1
      col = 0
      ensure_row()
    end
    set_cell_append(ch, w)
    if col >= tw then
      pending_wrap = true
      col = tw -- stay; next char wraps
    end
  end

  local function strip_sgr(s)
    return (s:gsub("\27%[[0-9;]*m", ""))
  end

  local function feed(raw)
    raw = tostring(raw or "")
    local i = 1
    while i <= #raw do
      local c = raw:sub(i, i)
      if c == "\27" then
        local rest = raw:sub(i)
        -- CSI
        local n1, cmd = rest:match("^\27%[(%d*)([A-Za-z])")
        if cmd then
          local n = tonumber(n1) or (cmd == "A" and 1 or 0)
          if cmd == "A" then
            row = math.max(1, row - n)
            col = 0
            pending_wrap = false
          elseif cmd == "K" then
            -- 2K = erase entire line (n defaults: 0 = to end, 2 = entire)
            local full = rest:match("^\27%[2K")
            ensure_row()
            if full or (n1 == "2") then
              lines[row] = ""
              col = 0
            else
              -- erase from cursor to end: truncate visual at col
              local cur, acc, pos = lines[row], "", 0
              for p, cp in utf8.codes(cur) do
                local ch = utf8.char(cp)
                local w = (cp == 0x09) and (8 - (pos % 8)) or (ref_cp_width(cp) or 1)
                if pos + w > col then break end
                acc = acc .. ch
                pos = pos + w
              end
              lines[row] = acc
            end
            pending_wrap = false
          elseif cmd == "J" then
            -- 0J erase from cursor to end of screen
            ensure_row()
            lines[row] = lines[row] or ""
            -- clear rest of current line from col
            local cur, acc, pos = lines[row], "", 0
            for p, cp in utf8.codes(cur) do
              local ch = utf8.char(cp)
              local w = (cp == 0x09) and (8 - (pos % 8)) or (ref_cp_width(cp) or 1)
              if pos + w > col then break end
              acc = acc .. ch
              pos = pos + w
            end
            lines[row] = acc
            for r = row + 1, #lines do lines[r] = "" end
            pending_wrap = false
          end
          local m = rest:match("^\27%[[0-9;]*[A-Za-z]")
          i = i + #m
        elseif rest:match("^\27%[[0-9;]*m") then
          local m = rest:match("^\27%[[0-9;]*m")
          i = i + #m -- skip SGR
        else
          i = i + 1
        end
      elseif c == "\n" then
        row = row + 1
        col = 0
        pending_wrap = false
        ensure_row()
        i = i + 1
      elseif c == "\r" then
        col = 0
        pending_wrap = false
        i = i + 1
      else
        -- utf8 char
        local p = utf8.offset(raw, 2, i)
        local last = p and (p - 1) or #raw
        local ch = raw:sub(i, last)
        local cp = utf8.codepoint(ch)
        local w
        if cp == 0x09 then
          w = 8 - (col % 8)
        else
          w = ref_cp_width(cp) or 1
        end
        put_char(ch, w)
        i = last + 1
      end
    end
  end

  local function snapshot()
    ensure_row()
    -- trim trailing empty lines for display, keep structure
    local out = {}
    local last = 1
    for i = 1, #lines do
      if lines[i] ~= "" then last = i end
    end
    for i = 1, math.max(last, row) do
      out[i] = strip_sgr(lines[i] or "")
    end
    return out, row, col
  end

  return { feed = feed, snapshot = snapshot, strip = strip_sgr }
end

-- ── Capture io.write + fix tw ───────────────────────────────────────────────
local core = require("ui.core")
local function with_tw(tw, fn)
  core.invalidate_size()
  local orig = core.tw
  core.tw = function() return tw end
  local ok, err = pcall(fn)
  core.tw = orig
  core.invalidate_size()
  if not ok then error(err) end
end

local function capture(fn)
  local buf, real = {}, io.write
  io.write = function(...)
    for _, v in ipairs({ ... }) do buf[#buf + 1] = tostring(v) end
    return real
  end
  local ok, err = pcall(fn)
  io.write = real
  if not ok then error(err) end
  return table.concat(buf)
end

local executor = require("ui.tools_init.executor")

local function run_exec_path(tw, lines_chunk, final_out)
  local cmd = "Exec | echo test"
  local raw
  with_tw(tw, function()
    raw = capture(function()
      executor.tool_start(cmd)
      for _, ln in ipairs(lines_chunk) do
        executor.tool_chunk(ln)
      end
      executor.tool_end(cmd, final_out or table.concat(lines_chunk, "\n"), true)
    end)
  end)
  local term = new_term(tw)
  term.feed(raw)
  local screen = term.snapshot()
  return raw, screen, term
end

local function count_header(screen, name)
  local n = 0
  for _, ln in ipairs(screen) do
    if ln:find(name, 1, true) then n = n + 1 end
  end
  return n
end

local function has_yellow_residue(raw, screen)
  -- After tool_end, yellow SGR near Exec should not remain as a visible orphan header.
  -- Screen lines: only one "Exec" expected (final green/red header redraw).
  return count_header(screen, "Exec") > 1
end

local function print_screen(label, screen)
  print("--- tela " .. label .. " ---")
  for i, ln in ipairs(screen) do
    print(string.format("%2d|%s", i, ln))
  end
end

-- ── C1: emoji near limit ────────────────────────────────────────────────────
for _, tw in ipairs({ 40, 80 }) do
  local lines = {
    "xx ✅✅ mid ❌❌ end",
    "yy ✅✅ mid ❌❌ end",
    "zz ✅✅ mid ❌❌ end",
  }
  local raw, screen = run_exec_path(tw, lines)
  local n_exec = count_header(screen, "Exec")
  T(n_exec == 1, "C1 tw=" .. tw .. " uma unica linha Exec (got " .. n_exec .. ")")
  T(not has_yellow_residue(raw, screen), "C1 tw=" .. tw .. " sem cabecalho residual duplicado")
  -- body content visible
  local blob = table.concat(screen, "\n")
  T(blob:find("✅", 1, true) ~= nil, "C1 tw=" .. tw .. " conteudo emoji no card final")
  if n_exec ~= 1 then print_screen("C1-" .. tw, screen) end
end

-- ── C2: tabs ────────────────────────────────────────────────────────────────
do
  local tw = 40
  local lines = { "a\tb\tc", "\tstart", "end\t\txx" }
  local raw, screen = run_exec_path(tw, lines)
  T(count_header(screen, "Exec") == 1, "C2 uma unica linha Exec")
  T(not has_yellow_residue(raw, screen), "C2 sem residual")
end

-- ── C3: CJK near limit ──────────────────────────────────────────────────────
for _, tw in ipairs({ 40, 80 }) do
  local lines = {
    "日本語テキストABCDEF",
    "漢字テスト行番号二",
    "終わりの行ですXY",
  }
  local raw, screen = run_exec_path(tw, lines)
  local n = count_header(screen, "Exec")
  T(n == 1, "C3 tw=" .. tw .. " uma unica Exec (got " .. n .. ")")
  if n ~= 1 then print_screen("C3-" .. tw, screen) end
end

-- ── C4: long output + "... (N linhas)" rewrite ──────────────────────────────
do
  local tw = 40
  local chunks = {}
  for i = 1, 12 do
    chunks[i] = string.format("L%02d ✅ line content", i)
  end
  local raw, screen = run_exec_path(tw, chunks)
  T(count_header(screen, "Exec") == 1, "C4 uma unica Exec")
  -- rewrite sequence present in stream
  local rewrites = select(2, raw:gsub("\27%[1A\27%[2K", ""))
  T(rewrites >= 1, "C4 reescreveu linha ... (rewrites=" .. tostring(rewrites) .. ")")
  local blob = table.concat(screen, "\n")
  -- final body is collapsed (MAX_BODY=5): should not keep the partial "..." as orphan above
  T(count_header(screen, "Exec") == 1, "C4 sem residual de cabecalho")
  T(blob:find("L01", 1, true) ~= nil or blob:find("L1", 1, true) ~= nil
    or blob:find("✅", 1, true) ~= nil, "C4 corpo final redesenhado")
end

-- ── C5: control without wide chars ──────────────────────────────────────────
do
  local tw = 40
  local lines = { "plain one", "plain two", "plain three" }
  local raw, screen = run_exec_path(tw, lines)
  T(count_header(screen, "Exec") == 1, "C5 uma unica Exec")
  local blob = table.concat(screen, "\n")
  T(blob:find("plain one", 1, true) ~= nil, "C5 corpo plain visivel")
end

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
