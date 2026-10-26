-- tests/config_isolation_spec.lua — Garante que os specs de permissão não alteram o config real.
-- Compara ~/.TermAI/config.json antes e depois de cada spec. Se mudar, falha e restaura.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local pass, fail = 0, 0
local function T(name, ok, detail)
  if ok then
    pass = pass + 1
    print("  ✅ " .. name)
  else
    fail = fail + 1
    print("  ❌ " .. name .. (detail and (" — " .. detail) or ""))
  end
end

local function caminho_config_real()
  local home = os.getenv("HOME")
  return home and (home .. "/.TermAI/config.json") or nil
end

local function ler_arquivo(caminho)
  if not caminho then return nil end
  local f = io.open(caminho, "r")
  if not f then return nil end
  local conteudo = f:read("*a")
  f:close()
  return conteudo
end

local function restaurar_arquivo(caminho, conteudo)
  if not caminho or conteudo == nil then return end
  local f = io.open(caminho, "w")
  if f then f:write(conteudo); f:close() end
end

local function specs_de_permissao()
  local lista = {}
  local p = io.popen("ls -1 tests/permissions_*_spec.lua tests/exec_permissions*.lua 2>/dev/null")
  if not p then return lista end
  for linha in p:lines() do lista[#lista + 1] = linha end
  p:close()
  return lista
end

print("\n=== Specs de permissão não alteram ~/.TermAI/config.json ===")
local caminho = caminho_config_real()
local antes = ler_arquivo(caminho)
if antes == nil then
  print("  (sem config real neste ambiente: qualquer spec que criar o arquivo falha)")
end

for _, spec in ipairs(specs_de_permissao()) do
  os.execute(string.format("lua5.4 '%s' > /dev/null 2>&1", spec))
  local depois = ler_arquivo(caminho)
  local alterou = depois ~= antes
  T(spec .. " não altera o config real", not alterou, "config do usuário foi alterado")
  if alterou then restaurar_arquivo(caminho, antes) end
  antes = ler_arquivo(caminho)
end

print(string.format("\nRESULTADO ISOLAMENTO DO CONFIG: %d passaram, %d falharam", pass, fail))
if fail > 0 then os.exit(1) end
