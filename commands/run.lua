-- Execução não interativa para rotinas agendadas: TermAI run --prompt-file FILE [--model provider/model].
local config = require("config")
local session = require("session")

local function read_file(path)
  local f, err = io.open(path, "r")
  if not f then return nil, err end
  local content = f:read("*a")
  f:close()
  return content
end

local model_ref, prompt_file, prompt_text, max_iter
local i = 2
while i <= #arg do
  local a = arg[i]
  if a == "--model" then model_ref = arg[i+1]; i = i + 2
  elseif a == "--prompt-file" then prompt_file = arg[i+1]; i = i + 2
  elseif a == "--prompt" then prompt_text = arg[i+1]; i = i + 2
  elseif a == "--max-iter" then max_iter = tonumber(arg[i+1]); i = i + 2
  elseif a == "--help" or a == "-h" then
    print("Uso: TermAI run --prompt-file /caminho/prompt.md [--model provider/model] [--max-iter N]")
    return
  else
    io.stderr:write("Argumento desconhecido: " .. tostring(a) .. "\n")
    os.exit(2)
  end
end

if prompt_file then
  local text, err = read_file(prompt_file)
  if not text then io.stderr:write("Não foi possível ler o prompt: " .. tostring(err) .. "\n"); os.exit(2) end
  prompt_text = text
end
if not prompt_text or prompt_text == "" then
  io.stderr:write("Informe --prompt-file ou --prompt.\n")
  os.exit(2)
end

local cfg = config.load()
if model_ref and model_ref ~= "" then
  local ok = config.set("agents.defaults.model.primary", model_ref)
  if not ok then io.stderr:write("Não foi possível salvar o modelo primário.\n"); os.exit(2) end
end

-- Sessão isolada por execução: evita misturar o contexto de jobs anteriores.
session.init((cfg.agents and cfg.agents.defaults and cfg.agents.defaults.session) or {})
session.new()

local context = require("agent.context")
local ctx = context.build()
if max_iter and max_iter > 0 then ctx.MAX_ITER = max_iter end
local before = #ctx.msgs
local loop = require("agent.loop")
local persistence = require("agent.main_loop.persistence")
local response, elapsed, _, overflow, stream_complete, reasoning =
  loop.rodar(ctx, prompt_text, "user")

persistence.save_exchange(ctx, before, reasoning or "", prompt_text,
  ctx.tokens_fresh, {}, stream_complete)

local result = tostring(response or "")
print("\n[TERMAI_RUN] model=" .. tostring(ctx.active.ref)
  .. " elapsed=" .. tostring(elapsed or 0)
  .. " stream_complete=" .. tostring(stream_complete)
  .. " overflow=" .. tostring(overflow))
if result:match("^%[ERRO") or overflow or result == "" then
  if result == "" then result = "Sem resposta final (limite de iterações ou resposta vazia)." end
  io.stderr:write("[TERMAI_RUN] Falha: " .. result .. "\n")
  os.exit(1)
end
