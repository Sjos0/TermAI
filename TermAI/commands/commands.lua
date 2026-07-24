local available = require("commands.available")
local ui = require("commands.models.ui")
local c = ui.c
local M = {}

function M.run()
  while true do
    ui.header("Comandos Disponíveis na TUI")

    for i, cmd in ipairs(available.commands) do
      io.write("  " .. c.white .. i .. "." .. c.reset)
      io.write(" " .. c.cyan .. cmd.name .. c.reset)
      local pad_len = 14 - #cmd.name
      if pad_len < 1 then pad_len = 1 end
      io.write(string.rep(" ", pad_len))
      io.write(c.gray .. cmd.desc .. c.reset .. "\n")
    end

    io.write("\n  " .. c.white .. "0." .. c.reset .. " Voltar\n\n")

    local ch = ui.prompt_read("Escolha")

    if not ch or ch == "0" or ch == "" then
      io.write(c.gray .. "  Voltando ao chat...\n\n" .. c.reset)
      return nil
    end

    local idx = tonumber(ch)
    if idx and available.commands[idx] then
      return available.commands[idx].name
    end

    for _, cmd in ipairs(available.commands) do
      if ch == cmd.name or ch == cmd.name:sub(2) then
        return cmd.name
      end
    end

    io.write(c.red .. "  Opção inválida.\n" .. c.reset)
    ui.pause()
  end
end

return M
