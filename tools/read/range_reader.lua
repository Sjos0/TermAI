local M = {}

function M.read(file_path, content, info, ls, le)
  local out, i = {}, 0
  local has_trailing = content:sub(-1) == "\n"
  local temp = has_trailing and content:sub(1, -2) or content
  for line in (temp .. "\n"):gmatch("([^\n]*)\n") do
    i = i + 1
    if i >= ls and i <= le then
      if #line > 2000 then
        line = line:sub(1, 2000) .. " ... [Linha truncada: " .. (#line - 2000) .. " caracteres omitidos]"
      end
      out[#out+1] = string.format("%4d │ %s", i, line)
    end
  end
  if #out == 0 then
    return "❌ Intervalo L" .. ls .. "-L" .. le .. " vazio ou fora do arquivo."
  end
  return "📄 " .. file_path .. "  L" .. ls .. "-L" .. le .. "\n"
      .. info .. "\n"
      .. table.concat(out, "\n")
end

return M
