-- tools/exec/permissions_ui/parte_1.lua — exporta: _enter_modal_screen, _leave_modal_screen, show_dialog.
return function(M, N)
  local approval_backend, enter_modal_screen, leave_modal_screen, run_dialog = N.approval_backend, N.enter_modal_screen, N.leave_modal_screen, N.run_dialog


  -- Expostos só para testes unitários do lifecycle
  M._enter_modal_screen = enter_modal_screen

  M._leave_modal_screen = leave_modal_screen


  function M.show_dialog(tool_name, command, failed_sub, warnings, unknown_cmd)
    local backend = approval_backend.tool_backend()
    if backend then return backend(tool_name, command, failed_sub, warnings) end

    -- 1. Entra no modal
    enter_modal_screen()

    -- 2. Roda o diálogo com garantia de leave mesmo em erro
    local ok, a, b, c, d, e = xpcall(function()
      return run_dialog(tool_name, command, failed_sub, warnings, unknown_cmd)
    end, debug.traceback)

    -- 3. SEMPRE sai do modal (tela principal restaurada pelo terminal)
    leave_modal_screen()

    if not ok then
      -- a = traceback; propaga sem deixar o usuário preso na alternate screen
      error(a, 0)
    end

    -- 4. Status só na tela principal
    local decision, pattern, color, icon, label = a, b, c, d, e
    local rs = "\27[0m"
    io.write(color .. "  " .. icon .. " " .. label .. rs .. "\n\n")
    io.flush()

    return decision, pattern
  end
end
