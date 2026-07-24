local M = {}

function M.read(file_path, content, info)
  local out = {}
  local i = 0
  local has_trailing = content:sub(-1) == "\n"
  local temp = has_trailing and content:sub(1, -2) or content
  for line in (temp .. "\n"):gmatch("([^\n]*)\n") do
    i = i + 1
    if #line > 2000 then
      line = line:sub(1, 2000) .. " ... [Linha truncada: " .. (#line - 2000) .. " caracteres omitidos]"
    end
    out[#out+1] = string.format("%4d │ %s", i, line)
  end
  return "📄 " .. file_path .. "\n" .. info .. "\n\n" .. table.concat(out, "\n")
end

return M
