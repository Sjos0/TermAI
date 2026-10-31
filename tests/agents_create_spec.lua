package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
-- tests/agents_create_spec.lua — Criação de agentes independentes (agents_create).
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local portable_tmp = require("tests.helpers.tmp")

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local root = portable_tmp.name("termai_agents_test")
os.execute("mkdir -p '" .. root .. "/workspace'")

-- Isola config e raiz: nada toca no ~/.TermAI real.
require("config.store").PATH = root .. "/config.json"
require("config.store")._data = nil
local paths = require("tools.agents.paths")
paths.base_override = root

local function write(path, s) local f = io.open(path, "w"); f:write(s); f:close() end
local function read(path) local f = io.open(path, "r"); if not f then return nil end; local s = f:read("*a"); f:close(); return s end

write(root .. "/workspace/USER.md", "Samuka: desenvolvedor independente.\n")

local create = require("tools.agents.create")

check(create.create({ id = "pesquisa", identity = "x", functions = "y" }):match("^%[FAIL%]") ~= nil,
  "sem confirmed=true é recusado")
check(create.create({ id = "main", identity = "x", functions = "y", confirmed = true }):match("inválido") ~= nil,
  "id 'main' é reservado")
check(create.create({ id = "Bad Id", identity = "x", functions = "y", confirmed = true }):match("inválido") ~= nil,
  "id com espaço/maiúscula é recusado")
check(create.create({ id = "pesquisa", identity = " ", functions = "y", confirmed = true }):match("identity") ~= nil,
  "identidade vazia é recusada")

local ok_msg = create.create({ id = "pesquisa", name = "Pesquisador", identity = "Metódico e direto.",
  functions = "Pesquisar na web e resumir fontes.", confirmed = true })
check(ok_msg:match("^%[OK%]") ~= nil, "criação válida retorna sucesso")

local dir = paths.workspace_abs("pesquisa")
local identity = read(dir .. "/IDENTITY.md") or ""
local agents_md = read(dir .. "/AGENTS.md") or ""
local user_md = read(dir .. "/USER.md") or ""
check(identity:find("# Pesquisador", 1, true) ~= nil, "nome vai para o topo do IDENTITY.md")
check(identity:find("Metódico e direto.", 1, true) ~= nil, "identidade vai para IDENTITY.md")
check(agents_md:find("Pesquisar na web", 1, true) ~= nil, "funções vão para AGENTS.md")
check(user_md == read(root .. "/workspace/USER.md"), "USER.md copiado do orquestrador (idêntico)")

local cfg_list = require("config").get("agents.list") or {}
local entry
for _, a in ipairs(cfg_list) do if a.id == "pesquisa" then entry = a end end
check(entry ~= nil and entry.workspace == "agents/pesquisa/workspace", "entrada registrada em agents.list")
check(entry ~= nil and entry.disabled_tools[1] == "agents_create", "agente criado não pode criar outros agentes")
check(cfg_list[1] and cfg_list[1].id == "main", "orquestrador continua como primeiro da lista")

check(create.create({ id = "pesquisa", identity = "x", functions = "y", confirmed = true }):match("já existe") ~= nil,
  "id repetido é recusado")

print(failures == 0 and "\nTODOS OS TESTES PASSARAM" or ("\n" .. failures .. " FALHA(S)"))
os.exit(failures == 0 and 0 or 1)
