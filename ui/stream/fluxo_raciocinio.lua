-- ui/stream/fluxo_raciocinio.lua — stream_reasoning: caixa de raciocínio durante o streaming.
return function(M, N)
  local core, spinner, state, ansi, box, c, get_thinking_mode = N.core, N.spinner, N.state, N.ansi, N.box, N.c, N.get_thinking_mode
  function M.stream_reasoning(tok)
    if N.ESTADO.sink then return N.ESTADO.sink.reasoning(tok) end
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

end
