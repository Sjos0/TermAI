-- graph_builder.lua — Construção do grafo: índice invertido + co-ocorrências por arquivo.
local io_utils   = require("tools.memory.io_utils")
local tag_parser = require("tools.memory.tag_parser")
local M = {}

-- Extrai tags + snippets de um arquivo. Reaproveita o cache quando o tamanho
-- em bytes do conteúdo não mudou desde o último boot — pula o regex caro de
-- extract_tags/get_snippet, que é o gargalo real do rebuild no boot/restart.
local function parse_file(filepath, content, cached_entry)
  local filename = filepath:match("([^/]+)$") or filepath
  local date     = filename:match("^(%d%d%d%d%-%d%d%-%d%d)") or filename
  local size     = #content

  if cached_entry and cached_entry.size == size then
    return cached_entry.tags, cached_entry.snippets, date, filename, size
  end

  local tags = tag_parser.extract_tags(content)
  local snippets = {}
  local lower_content = content:lower()
  for _, tag in ipairs(tags) do
    snippets[tag] = tag_parser.get_snippet(content, tag, nil, lower_content)
  end
  return tags, snippets, date, filename, size
end

-- Constrói o grafo a partir da lista de arquivos. `cached_entries` (opcional,
-- path -> {size,date,file,tags,snippets}) permite pular o parse de arquivos
-- inalterados. Sem cache, o comportamento é idêntico ao build_graph original.
-- Retorna: graph, entries (para persistir via graph_cache.save)
local function build_graph(files, cached_entries)
  local graph = {
    -- Índice invertido: tag → lista de entradas {file, date, path, snippet}
    index = {},
    -- Nós do grafo: path → {date, tags, content, file}
    nodes = {},
    -- Arestas: tag → {tag_relacionada, ...} (co-ocorrência no mesmo arquivo)
    edges = {},
  }
  local entries_out = {}

  for _, filepath in ipairs(files) do
    local content = io_utils.read_file(filepath)
    if content and content ~= "" then
      local cached_entry = cached_entries and cached_entries[filepath]
      local tags, snippets, date, filename, size = parse_file(filepath, content, cached_entry)

      -- Salva o nó
      graph.nodes[filepath] = {
        date    = date,
        tags    = tags,
        content = content,
        file    = filename,
      }

      entries_out[filepath] = {
        size = size, date = date, file = filename, tags = tags, snippets = snippets,
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
          snippet = snippets[tag],
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

  return graph, entries_out
end

M.build_graph = build_graph
return M
