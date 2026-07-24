-- io_utils.lua — Utilitários de I/O: diretório de memória, listar e ler arquivos .md.
local HOME       = os.getenv("HOME") or "/data/data/com.termux/files/home"
local MEMORY_DIR = HOME .. "/.TermAI/workspace/memory"
local M = {}

local function list_md_files(dir)
  local files = {}
  local h = io.popen('find "' .. dir .. '" -name "*.md" 2>/dev/null | sort -r')
  if not h then return files end
  for line in h:lines() do
    files[#files + 1] = line
  end
  h:close()
  return files
end

local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  return content
end

M.MEMORY_DIR    = MEMORY_DIR
M.list_md_files = list_md_files
M.read_file     = read_file
return M
