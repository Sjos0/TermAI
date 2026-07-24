-- graph_builder.lua — Construção do grafo: índice invertido + co-ocorrências por arquivo.
local io_utils   = require("tools.memory.io_utils")
local tag_parser = require("tools.memory.tag_parser")
local M = {}

local function build_graph(files)
  local graph = {
    -- Índice invertido: tag → lista de entradas {file, date, path, snippet}
    index = {},
    -- Nós do grafo: path → {date, tags, content, file}
    nodes = {},
    -- Arestas: tag → {tag_relacionada, ...} (co-ocorrência no mesmo arquivo)
    edges = {},
  }

  for _, filepath in ipairs(files) do
    local content = io_utils.read_file(filepath)
    if content and content ~= "" then
      local filename = filepath:match("([^/]+)$") or filepath
      local date     = filename:match("^(%d%d%d%d%-%d%d%-%d%d)") or filename

      local tags = tag_parser.extract_tags(content)

      -- Salva o nó
      graph.nodes[filepath] = {
        date    = date,
        tags    = tags,
        content = content,
        file    = filename,
      }

      -- Popula o índice invertido
      for _, tag in ipairs(tags) do
        if not graph.index[tag] then
          graph.index[tag] = {}
        end
        graph.index[tag][#graph.index[tag] + 1] = {
          file    = filename,
          path    = filepath,
          date    = date,
          snippet = tag_parser.get_snippet(content, tag),
        }
      end

      -- Constrói arestas por co-ocorrência
      for i = 1, #tags do
        if not graph.edges[tags[i]] then
          graph.edges[tags[i]] = {}
        end
        for j = 1, #tags do
          if i ~= j then
            -- Verifica se a aresta já existe
            local exists = false
            for _, rel in ipairs(graph.edges[tags[i]]) do
              if rel == tags[j] then exists = true; break end
            end
            if not exists then
              graph.edges[tags[i]][#graph.edges[tags[i]] + 1] = tags[j]
            end
          end
        end
      end
    end
  end

  return graph
end

M.build_graph = build_graph
return M
