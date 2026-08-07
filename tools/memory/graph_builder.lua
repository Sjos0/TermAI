-- graph_builder.lua — Construção e atualização incremental do grafo de memória.
-- v2.1: sem content no cache; limpeza completa de arestas; get_mtime batch-friendly.
local io_utils   = require("tools.memory.io_utils")
local tag_parser = require("tools.memory.tag_parser")

local M = {}

local function get_mtime(filepath)
  local h = io.popen('stat -c %Y "' .. filepath .. '" 2>/dev/null')
  if not h then return "0" end
  local val = h:read("*l")
  h:close()
  if val and val:match("^%d+$") then return val end
  return "0"
end

M.get_mtime = get_mtime

local function parse_file(filepath, content)
  local filename = filepath:match("([^/]+)$") or filepath
  local date     = filename:match("^(%d%d%d%d%-%d%d%-%d%d)") or filename
  local tags     = tag_parser.extract_tags(content)
  local snippets = {}
  local lower_content = content:lower()
  for _, tag in ipairs(tags) do
    snippets[tag] = tag_parser.get_snippet(content, tag, nil, lower_content)
  end
  return tags, snippets, date, filename
end

local function remove_graph_node(graph, path)
  local node = graph.nodes[path]
  if not node then return end

  local removed_tags = {}
  for _, tag in ipairs(node.tags or {}) do
    removed_tags[tag] = true
    local entries = graph.index[tag]
    if entries then
      local new_entries = {}
      for _, e in ipairs(entries) do
        if e.path ~= path then
          new_entries[#new_entries + 1] = e
        end
      end
      if #new_entries == 0 then
        graph.index[tag] = nil
        graph.edges[tag] = nil
      else
        graph.index[tag] = new_entries
      end
    end
  end

  -- Limpa referências órfãs: só mantém arestas para tags que ainda existem no índice
  for t, rels in pairs(graph.edges) do
    local final = {}
    for _, r in ipairs(rels) do
      if graph.index[r] then
        final[#final + 1] = r
      end
    end
    if #final == 0 then
      graph.edges[t] = nil
    else
      graph.edges[t] = final
    end
  end

  graph.nodes[path] = nil
end

M.remove_graph_node = remove_graph_node

local function update_graph_node(graph, filepath)
  local content = io_utils.read_file(filepath)
  if not content or content == "" then
    remove_graph_node(graph, filepath)
    return false
  end

  if graph.nodes[filepath] then
    remove_graph_node(graph, filepath)
  end

  local tags, snippets, date, filename = parse_file(filepath, content)

  graph.nodes[filepath] = {
    date    = date,
    tags    = tags,
    content = content, -- RAM only; graph_cache.save stripa isso
    file    = filename,
  }

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

  for i = 1, #tags do
    if not graph.edges[tags[i]] then
      graph.edges[tags[i]] = {}
    end
    for j = 1, #tags do
      if i ~= j then
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

  return true
end

M.update_graph_node = update_graph_node

local function build_graph_full(files)
  local graph = { index = {}, nodes = {}, edges = {} }
  local file_hashes = {}

  for _, filepath in ipairs(files) do
    if update_graph_node(graph, filepath) then
      file_hashes[filepath] = get_mtime(filepath)
    end
  end

  return graph, file_hashes
end

M.build_graph_full = build_graph_full

local function build_graph(files, _cached_entries)
  return build_graph_full(files)
end

M.build_graph = build_graph

return M
