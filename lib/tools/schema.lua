-- lib/tools/schema.lua — get_schema e get_docs, com filtro de tools desativadas e ordem estável.
return function(tools, helpers, json, to_disabled_set)
  --- get_schema([disabled_set])
  -- disabled_set: tabela de lookup { Name = true, ... } ou array de nomes.
  -- Omite tools desativadas; mantém ordem estável (table.sort).
  -- Retorna nil se nenhuma tool com schema restar.
  function tools.get_schema(disabled)
    local dset = to_disabled_set(disabled)
    local names = {}
    for name, data in pairs(tools.registry) do
      if data.schema and not dset[name] then
        names[#names + 1] = name
      end
    end
    table.sort(names)
    local schema = {}
    for _, name in ipairs(names) do
      local data = tools.registry[name]
      schema[#schema + 1] = {
        type = "function",
        ["function"] = {
          name        = name,
          description = data.desc,
          parameters  = data.schema,
        }
      }
    end
    return #schema > 0 and schema or nil
  end

  --- get_docs([disabled_set]) — mesmo filtro do schema, para system prompt / listagens.
  function tools.get_docs(disabled)
    local dset = to_disabled_set(disabled)
    local doc = "FERRAMENTAS NATIVAS DISPONÍVEIS:\n"
    local names = {}
    for name in pairs(tools.registry) do
      if not dset[name] then names[#names + 1] = name end
    end
    table.sort(names)
    for _, name in ipairs(names) do
      local data = tools.registry[name]
      doc = doc .. "- " .. name .. ": " .. data.desc .. "\n"
    end
    return doc
  end
end
