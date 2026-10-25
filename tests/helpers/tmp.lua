-- tests/helpers/tmp.lua — Diretório temporário gravável para os specs.
-- No Termux, /tmp é somente leitura: os specs não podem fixar "/tmp" nem usar
-- os.tmpname() direto. Este helper escolhe o primeiro candidato que aceita escrita.
local M = {}

local cached
local sentinel

-- Verdadeiro só se o diretório aceita escrita de fato (não só se existe).
local function writable(dir)
  if not dir or dir == "" then return false end
  local probe = dir .. "/.probe_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000000))
  local f = io.open(probe, "w")
  if not f then return false end
  f:close()
  os.remove(probe)
  return true
end

-- Lista de candidatos na ordem de preferência. Entradas vazias ou nil são descartadas.
function M.default_candidates(env)
  env = env or os.getenv
  local home = env("HOME") or ""
  local list = {
    "/tmp",
    env("TMPDIR"),
    home ~= "" and (home .. "/.TermAI/workspace/tmp") or nil,
    home ~= "" and home or nil,
  }
  local out = {}
  for _, c in ipairs(list) do
    if c and c ~= "" then out[#out + 1] = c end
  end
  return out
end

-- Escolhe o primeiro candidato gravável e cria um subdiretório único dentro dele.
-- Devolve o caminho ou nil (função pura: não usa cache, ideal para testes).
function M.resolve(candidates)
  for _, base in ipairs(candidates) do
    if writable(base) then
      local dir = base .. "/termai_test_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000000))
      os.execute("mkdir -p '" .. dir .. "'")
      if writable(dir) then return dir end
    end
  end
  return nil
end

-- Diretório temporário do processo atual (resolvido uma vez e reutilizado).
function M.dir()
  if cached then return cached end
  cached = M.resolve(M.default_candidates())
  if not cached then
    error("nenhum diretório temporário gravável (ver tests/helpers/tmp.lua)")
  end
  return cached
end

-- Caminho novo dentro do diretório temporário (o arquivo/pasta não é criado aqui).
function M.name(suffix)
  return M.dir() .. "/" .. (suffix or "tmp") .. "_" .. tostring(math.random(1000000))
end

-- Remove o diretório temporário. Também roda ao fim do processo, se o spec não chamar.
function M.cleanup()
  if cached then
    os.execute("rm -rf '" .. cached .. "'")
    cached = nil
  end
end

-- Sentinela: quando o Lua fecha o estado normalmente, o __gc faz a limpeza.
-- (os.exit(n) sem close não roda finalizers; por isso o cleanup explícito continua valendo.)
sentinel = setmetatable({}, { __gc = function() M.cleanup() end })
M._sentinel = sentinel

return M
