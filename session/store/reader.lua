-- session/store/reader.lua — Subsistema de leitura segura e processamento de JSONL.
local json = require("json")
local common = require("session.store.common")

local M = {}

-- ── Leitura de todas as entradas (Completo) ─────────────────────────
function M.read_entries(session_id)
  local path = common.jsonl_path(session_id)
  local f = io.open(path, "r")
  if not f then return {} end
  local entries = {}
  local corrupt_count = 0
  for line in f:lines() do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= "" then
      local ok, e = pcall(json.decode, trimmed)
      if ok and type(e) == "table" then
        entries[#entries + 1] = e
      else
        corrupt_count = corrupt_count + 1
      end
    end
  end
  f:close()
  if corrupt_count > 0 then
    io.write(string.format("\27[38;5;208m⚠️  [Medula] %d linha(s) corrompida(s) ignorada(s) no histórico (%s)\27[0m\n",
      corrupt_count, session_id))
    io.flush()
  end
  return entries
end

-- ── Leitura de entradas ATIVAS (Otimização Lazy Loading) ────────────────────
-- Carrega strings cruas rapidamente e decodifica apenas o cabeçalho e mensagens
-- posteriores à última compactação, ignorando o lixo antigo do JSONL.
function M.read_active_entries(session_id)
  local path = common.jsonl_path(session_id)
  local f = io.open(path, "r")
  if not f then return {} end

  local raw_lines = {}
  for line in f:lines() do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= "" then
      raw_lines[#raw_lines + 1] = trimmed
    end
  end
  f:close()

  if #raw_lines == 0 then return {} end

  -- 1. Varre de trás para frente procurando a última compactação
  local last_comp_idx = nil
  for i = #raw_lines, 1, -1 do
    if raw_lines[i]:match('"type"%s*:%s*"compaction"') then
      last_comp_idx = i
      break
    end
  end

  local entries = {}
  local corrupt_count = 0

  -- 2. Monta índices a decodificar (cabeçalho da sessão sempre é o 1)
  local lines_to_decode = {}
  lines_to_decode[1] = 1

  if last_comp_idx and last_comp_idx > 1 then
    for i = last_comp_idx, #raw_lines do
      lines_to_decode[#lines_to_decode + 1] = i
    end
  else
    for i = 1, #raw_lines do
      lines_to_decode[i] = i
    end
  end

  -- 3. Decodificação segura das linhas selecionadas
  for _, idx in ipairs(lines_to_decode) do
    local ok, e = pcall(json.decode, raw_lines[idx])
    if ok and type(e) == "table" then
      entries[#entries + 1] = e
    else
      corrupt_count = corrupt_count + 1
    end
  end

  if corrupt_count > 0 then
    io.write(string.format("\27[38;5;208m⚠️  [Medula] %d linha(s) corrompida(s) ignorada(s) no histórico ativo (%s)\27[0m\n",
      corrupt_count, session_id))
    io.flush()
  end

  return entries
end

-- ── Leitura de mensagens (compatível com antigo e novo formato) ─────────────
function M.read_messages(session_id)
  local entries = M.read_entries(session_id)
  if #entries == 0 then return {} end
  local is_new = (entries[1].type == "session")
  if is_new then
    local msgs = {}
    for _, e in ipairs(entries) do
      if e.type == "message" then
        msgs[#msgs + 1] = e
      end
    end
    return msgs
  else
    return entries
  end
end

return M
