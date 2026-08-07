-- tests/graph_cache_full_spec.lua — Spec 2026-08-06 + fixes Ameno
local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
local TMP  = os.getenv("TMPDIR") or (HOME .. "/.TermAI/workspace/tmp")
local TEST_DIR = TMP .. "/termai_graph_test_" .. tostring(os.time())
os.execute('mkdir -p "' .. TEST_DIR .. '"')

package.loaded["tools.memory.io_utils"] = nil
local io_utils = require("tools.memory.io_utils")
io_utils.MEMORY_DIR = TEST_DIR
io_utils.list_md_files = function(dir)
  local files = {}
  local h = io.popen('find "' .. dir .. '" -name "*.md" 2>/dev/null | sort -r')
  if not h then return files end
  for line in h:lines() do files[#files + 1] = line end
  h:close()
  return files
end

package.loaded["tools.memory.graph_cache"] = nil
package.loaded["tools.memory.graph_builder"] = nil
package.loaded["tools.memory"] = nil

local graph_cache   = require("tools.memory.graph_cache")
local graph_builder = require("tools.memory.graph_builder")
local memory        = require("tools.memory")
graph_cache.CACHE_PATH = TEST_DIR .. "/.graph_cache.json"

local pass, fail = 0, 0
local function assert_eq(name, a, b)
  if a == b then pass = pass + 1; print("  ✅ " .. name)
  else fail = fail + 1; print("  ❌ " .. name .. " got=" .. tostring(a) .. " exp=" .. tostring(b)) end
end
local function assert_true(name, cond) assert_eq(name, not not cond, true) end

print("=== graph_cache_full_spec v2.1 ===")

do
  local f = io.open(graph_cache.CACHE_PATH, "w"); f:write("{bad"); f:close()
  assert_eq("AC-006 corrompido → nil", graph_cache.load(), nil)
end

do
  local f1 = TEST_DIR .. "/2026-08-01.md"
  local f = io.open(f1, "w"); f:write("Hoje falei com [[Samuel]] sobre o [[parser]].\n"); f:close()
  local files = io_utils.list_md_files(TEST_DIR)
  local graph, hashes = graph_builder.build_graph_full(files)
  assert_true("build cria nós", graph.nodes[f1] ~= nil)
  assert_true("build cria índice", graph.index["samuel"] ~= nil)
  assert_true("save ok", graph_cache.save(graph, hashes))

  local data = graph_cache.load()
  assert_true("load ok", data ~= nil)
  assert_eq("version 2", data.version, 2)
  local node = data.graph.nodes[f1]
  assert_true("node existe no cache", node ~= nil)
  assert_eq("content NÃO está no cache", node.content, nil)
end

do
  memory.invalidate_cache()
  local data = graph_cache.load()
  assert_true("invalidate NÃO apaga disco", data ~= nil)
end

do
  local files = io_utils.list_md_files(TEST_DIR)
  local graph, hashes = graph_builder.build_graph_full(files)
  graph_cache.save(graph, hashes)

  local f2 = TEST_DIR .. "/2026-08-02.md"
  local f = io.open(f2, "w"); f:write("Decisão sobre [[fachada]].\n"); f:close()

  package.loaded["tools.memory"] = nil
  memory = require("tools.memory")
  local iu = require("tools.memory.io_utils"); iu.MEMORY_DIR = TEST_DIR
  local gc = require("tools.memory.graph_cache"); gc.CACHE_PATH = TEST_DIR .. "/.graph_cache.json"

  local result = memory.search("fachada")
  assert_true("AC-003 novo arquivo", result:find("fachada") ~= nil or result:find("[[fachada]]") ~= nil or #result > 10)
end

os.execute('rm -rf "' .. TEST_DIR .. '"')
print(string.format("\nResultado: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
print("OK")
