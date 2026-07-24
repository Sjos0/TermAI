-- filetracking.lua — REQ-5: acumula read/created/edited files da sessão
-- atual com o `details` da última compactação persistida, formata o
-- bloco <workspace_attention> e monta o `details` a persistir na
-- próxima entry de compactação.
local M = {}

local function sorted_keys(set)
  local list = {}
  for p in pairs(set or {}) do list[#list + 1] = p end
  table.sort(list)
  return list
end

-- Retorna (attention_xml, details).
function M.accumulate(prev_details, session_files)
  local read_set, written_set, edited_set = {}, {}, {}

  if prev_details then
    for _, p in ipairs(prev_details.read_files or {}) do read_set[p] = true end
    for _, p in ipairs(prev_details.created_files or {}) do written_set[p] = true end
    for _, p in ipairs(prev_details.edited_files or {}) do edited_set[p] = true end
  end
  if session_files then
    for p in pairs(session_files.read.set or {}) do read_set[p] = true end
    for p in pairs(session_files.written.set or {}) do written_set[p] = true end
    for p in pairs(session_files.edited.set or {}) do edited_set[p] = true end
  end

  local read_list    = sorted_keys(read_set)
  local written_list = sorted_keys(written_set)
  local edited_list  = sorted_keys(edited_set)

  local attention_xml = ""
  if #read_list > 0 or #written_list > 0 or #edited_list > 0 then
    attention_xml = "\n\n<workspace_attention>"
    if #read_list > 0 then attention_xml = attention_xml .. "\n  <read_files>" .. table.concat(read_list, ", ") .. "</read_files>" end
    if #written_list > 0 then attention_xml = attention_xml .. "\n  <created_files>" .. table.concat(written_list, ", ") .. "</created_files>" end
    if #edited_list > 0 then attention_xml = attention_xml .. "\n  <edited_files>" .. table.concat(edited_list, ", ") .. "</edited_files>" end
    attention_xml = attention_xml .. "\n</workspace_attention>"
  end

  local details = {
    read_files    = read_list,
    created_files = written_list,
    edited_files  = edited_list,
  }

  return attention_xml, details
end

return M
