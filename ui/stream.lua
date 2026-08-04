-- stream.lua — Fachada + API pública de streaming do reasoning do modelo.
-- Interface pública: M.stream_start, M.stream_reasoning, M.stream_token, M.stream_end
local core    = require("ui.core")
local spinner = require("ui.spinner")
local state   = require("ui.stream.state")
local ansi    = require("ui.stream.ansi_helpers")
local box     = require("ui.stream.reasoning_box")
local c = core.c
local M = {}

-- Sink plugável: canais sem terminal real (ex: channels/telegram) registram
-- um sink alternativo via M.set_sink. Sem sink, comportamento inalterado.
local sink = nil
function M.set_sink(custom) sink = custom end

local function get_thinking_mode()
  local ok, config_mod = pcall(require, "config")
  if ok and config_mod then
    local ok_val, val = pcall(config_mod.get, "agents.defaults.thinking_mode")
    if ok_val and val then
      return val
    end
  end
  return "expanded"
end

function M.stream_start()
  if sink then return sink.start() end
  state.reset()
end

-- Chamado pelo streamer no instante em que o primeiro chunk válido da
-- tentativa chega (reasoning, content OU tool_call — não importa o tipo).
-- É o único ponto que sabe, de fato, que a fase de retry/spinner acabou.
function M.stream_confirm()
  if sink then return sink.confirm() end
  local s = state._s
  if s.started then return end
  local tmode = get_thinking_mode()
  if tmode ~= "compact" then
    spinner.kill_spinner()
  end
  spinner.clear_retry_lines()
  s.started = true
end

function M.stream_reasoning(tok)
  if sink then return sink.reasoning(tok) end
  local s = state._s
  local tmode = get_thinking_mode()

  if tmode == "compact" then
    if not s.reasoning_started then
      s.reasoning_started = true
      s.reasoning         = ""
      spinner.mark_reasoning_started()
    end
    s.reasoning = s.reasoning .. tok
    return
  end

  if not s.reasoning_started then
    io.write("\r\27[K")
    s.dots = 1
    state._last_dots_time = os.time()
    io.write(ansi.header_label(false, s.dots) .. "\n")
    io.write(c.dim .. c.gray .. " │ ")
    s.reasoning_started = true
    s.reasoning         = ""
    s.reasoning_lines   = 1
    s.reasoning_col     = 3
    s.phase             = "streaming"
    s.extra_lines       = 0
    s.box_lines         = 0
  end

  local term_w = core.tw()

  if s.phase == "streaming" then
    s.reasoning = s.reasoning .. tok
    local processed = tok:gsub("\n", "\n" .. c.dim .. c.gray .. " │ ")
    io.write(c.dim .. c.gray .. processed)
    io.flush()

    for _, cp in utf8.codes(tok) do
      if cp == 10 then
        s.reasoning_lines = s.reasoning_lines + 1
        s.reasoning_col   = 3
      else
        local cw = core.cp_width(cp)
        s.reasoning_col = s.reasoning_col + cw
        if s.reasoning_col > term_w then
          s.reasoning_lines = s.reasoning_lines + 1
          s.reasoning_col   = cw
        end
      end
    end

    if ansi.tick_dots() then ansi.update_header_dots() end

    if s.reasoning_lines >= 15 then
      s.phase = "collapsed"
      local visible, end_col = core.truncate_reasoning(s.reasoning, 14, term_w)
      s.reasoning_visible = visible
      local extra_text = s.reasoning:sub(#visible + 1)
      local extra, new_col = core.count_lines_in(extra_text, end_col, term_w)
      s.extra_lines   = extra
      s.reasoning_col = new_col

      local total = s.reasoning_lines
      if total < core.th() - 2 then
        io.write(string.format("\27[%dA", total))
        io.write("\r\27[J")
        box.render_collapsed(s.reasoning_visible, s.extra_lines)
      else
        s.box_lines = total
      end
    end

  elseif s.phase == "collapsed" then
    s.reasoning = s.reasoning .. tok
    local extra = 0
    for _, cp in utf8.codes(tok) do
      if cp == 10 then
        s.reasoning_col = 3
        extra = extra + 1
      else
        local cw = core.cp_width(cp)
        s.reasoning_col = s.reasoning_col + cw
        if s.reasoning_col > term_w then
          s.reasoning_col = cw
          extra = extra + 1
        end
      end
    end
    if extra > 0 then
      s.extra_lines = s.extra_lines + extra
      io.write("\27[1A\27[K")
      io.write(c.dim .. c.gray .. " │ (+ " .. s.extra_lines .. " linhas)\27[K" .. c.reset .. "\n")
      io.flush()
    end
    if ansi.tick_dots() then ansi.update_header_dots() end
  end
end

function M.stream_token(tok)
  if sink then return sink.token(tok) end
  local s = state._s
  local tmode = get_thinking_mode()
  if tmode == "compact" then
    if not s.compact_thinking_stopped then
      s.compact_thinking_stopped = true
      spinner.stop_thinking_and_print_compact()
    end
  else
    if s.reasoning_started then
      box.close_reasoning_box()
      s.reasoning_started = false
    end
  end
  s.full = s.full .. tok
end

-- MUDANÇA: retorna full E reasoning.
-- reasoning vai para o JSONL (exibição na recuperação).
-- Não entra em ctx.msgs — a API rejeitaria.
function M.stream_end()
  if sink then return sink.finish() end
  local s = state._s
  local tmode = get_thinking_mode()
  if tmode == "compact" then
    if not s.compact_thinking_stopped then
      s.compact_thinking_stopped = true
      spinner.stop_thinking_and_print_compact()
    end
  else
    if s.reasoning_started then
      box.close_reasoning_box()
      s.reasoning_started = false
    end
  end
  return s.full, s.reasoning or ""
end

return M
