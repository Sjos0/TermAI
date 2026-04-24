local json = require("json")
local ui = require("ui")
local mf = require("memoryflush")
local tools = require("tools")

local workspace = os.getenv("HOME").. "/.TermAI/workspace"
local MAX_ITER = 20
local prompt_module = require("prompt")

local function carregar()
  local f = io.open(os.getenv("HOME").. "/.TermAI/config.json", "r")
  if not f then print("[ERRO] config.json não encontrado!"); os.exit(1) end
  local ok, c = pcall(json.decode, f:read("*all")); f:close()
  if not ok then print("[ERRO] config.json inválido!"); os.exit(1) end
  return c
end

local config = carregar()
local tokens = 0
local sys = prompt_module.build(workspace, tools)
local msgs = {{role = "system", content = sys}}

local function api_raw(payload_str)
  local t = os.tmpname()
  local f = io.open(t, "w"); f:write(payload_str); f:close()
  local cmd = string.format('curl -s -X POST "%s" -H "Authorization: Bearer %s" -H "Content-Type: application/json" -d @%s', config.endpoint, config.api_key, t)
  local h = io.popen(cmd); local r = h:read("*a"); h:close(); os.remove(t)
  return r
end

local function pensar_sync(txt, role)
  table.insert(msgs, {role = role or "user", content = txt})
  local payload = {model = config.modelo, messages = msgs, temperature = 0.5, max_tokens = config.max_tokens}
  if config.reasoning then
    payload.include_reasoning = true
    if config.reasoning_effort then
      payload.reasoning = { effort = config.reasoning_effort }
    end
  end
  local pl = json.encode(payload)
  for i = 1, 10 do
    local r = api_raw(pl); local ok, rep = pcall(json.decode, r)
    if ok and rep.choices and rep.choices[1] then
      if rep.usage then tokens = rep.usage.total_tokens end
      local t = rep.choices[1].message.content or "[vazio]"
      table.insert(msgs, {role = "assistant", content = t}); return t
    end
    ui.loading("gw reconnecting ("..i.."/10)...")
    os.execute("sleep "..math.min(10, 2^i))
  end
  return "[ERRO DE COMUNICAÇÃO]"
end

local function pensar_stream(txt, role)
  table.insert(msgs, {role = role or "user", content = txt})
  local payload = {model = config.modelo, messages = msgs, temperature = 0.5, max_tokens = config.max_tokens, stream = true}
  if config.reasoning then
    payload.include_reasoning = true
    if config.reasoning_effort then
      payload.reasoning = { effort = config.reasoning_effort }
    end
  end
  local pl = json.encode(payload)
  local t = os.tmpname(); local f = io.open(t, "w"); f:write(pl); f:close()
  local cmd = string.format('curl -s -N -X POST "%s" -H "Authorization: Bearer %s" -H "Content-Type: application/json" -d @%s', config.endpoint, config.api_key, t)
  ui.stream_start()
  local h = io.popen(cmd)
  for line in h:lines() do
    if line:match("^data: ") then
      local data = line:sub(7)
      if data == "[DONE]" then break end
      local ok, chunk = pcall(json.decode, data)
      if ok and chunk then
        if chunk.usage then tokens = chunk.usage.total_tokens end
        local delta = chunk.choices and chunk.choices[1] and chunk.choices[1].delta
        if delta then
          local r_text = delta.reasoning or delta.reasoning_content
          if r_text and r_text ~= "" then ui.stream_reasoning(r_text) end
          if delta.content and delta.content ~= "" then ui.stream_token(delta.content) end
        end
      end
    end
  end
  h:close(); os.remove(t)
  local full = ui.stream_end()
  if full == "" then table.remove(msgs); return pensar_sync(txt, role) end
  table.insert(msgs, {role = "assistant", content = full})
  return full
end

local function parsear_tools(resp)
  local texto_limpo = resp
  local ferramentas = {}
  local texto_para_analise = resp:gsub("```.-```", "")
  for tool_block, nome, arg in texto_para_analise:gmatch("(<tool>%s*<name>(.-)</name>%s*<arg>(.-)</arg>%s*</tool>)") do
    ferramentas[#ferramentas + 1] = {nome = nome:match("^%s*(.-)%s*$"), arg = arg:match("^%s*(.-)%s*$")}
    local s, e = texto_limpo:find(tool_block, 1, true)
    if s then texto_limpo = texto_limpo:sub(1, s-1).. texto_limpo:sub(e+1) end
  end
  return texto_limpo:match("^%s*(.-)%s*$") or "", ferramentas
end

local function executar_tools(ferramentas)
  local resultados = {}
  for _, tool in ipairs(ferramentas) do
    local display = (tool.nome.." | "..tool.arg):gsub("\n", " ")
    if #display > 70 then display = display:sub(1,70).."..." end
    ui.tool_start(display)
    local out = tools.call(tool.nome.."|"..tool.arg)
    local ok = not out:match("^❌")
    ui.tool_end(display, out, ok)
    resultados[#resultados+1] = string.format("<tool_result name=\"%s\" status=\"%s\">\n%s\n</tool_result>", tool.nome, (ok and "ok" or "erro"), out)
  end
  return table.concat(resultados, "\n\n")
end

local function rodar_loop(input_inicial, role_inicial, max_iter)
  local cur_text = input_inicial
  local cur_role = role_inicial or "user"
  local iter = 0
  local elapsed = 0
  while iter < (max_iter or MAX_ITER) do
    iter = iter + 1
    ui.start_thinking()
    local resp = pensar_stream(cur_text, cur_role)
    elapsed = ui.stop_thinking()
    local texto, ferramentas = parsear_tools(resp)
    if #ferramentas > 0 then
      if texto ~= "" then ui.ai_msg_stream(texto) end
      cur_text = executar_tools(ferramentas)
      cur_role = "user"
      if resp:match("%[FLUSH_DONE%]") then return resp, elapsed, true end
    else
      ui.ai_msg_stream(resp)
      local flush_done = resp:match("%[FLUSH_DONE%]") ~= nil
      return resp, elapsed, flush_done
    end
  end
  ui.agent_limit(max_iter or MAX_ITER)
  return "", elapsed, false
end

local function banner_flush(tokens_agora, config)
  local linha = string.rep("━", 50)
  local estado = mf.estado(tokens_agora, config)
  io.write("\n\27[38;5;220m"..linha.."\27[0m\n\27[1m\27[38;5;220m 🧠 MEMORY FLUSH AUTOMÁTICO\27[0m\n")
  io.write("\27[38;5;245m tokens agora : "..tokens_agora.."\n próximo flush: "..estado.proximo.."\n (a cada "..estado.limite.." tokens)\27[0m\n\27[38;5;220m"..linha.."\27[0m\n\n")
  io.flush()
end

local function banner_compactacao(tokens_agora, config)
  local pct = math.floor((tokens_agora / config.max_contexto) * 100)
  local linha = string.rep("━", 50)
  io.write("\n\27[38;5;203m"..linha.."\27[0m\n\27[1m\27[38;5;203m ⚠️ COMPACTAÇÃO CRÍTICA — "..pct.."% atingido\27[0m\n")
  io.write("\27[38;5;245m Removendo metade mais antiga do histórico...\27[0m\n\27[38;5;203m"..linha.."\27[0m\n\n")
  io.flush()
end

ui.header(config.modelo)

while true do
  if config.limites then
    if mf.deve_compactar(tokens, config) then
      banner_compactacao(tokens, config)
      msgs = mf.compactar_msgs(msgs)
      ui.ai_msg_stream("✅ Compactação concluída. Histórico antigo removido.")
    end
    if mf.deve_flush(tokens, config) then
      banner_flush(tokens, config)
      local prompt = mf.get_flush_prompt(config)
      local _, _, done = rodar_loop(prompt, "user", MAX_ITER)
      if done then
        mf.marcar_flush(tokens)
        io.write("\27[38;5;114m ✅ Memory Flush concluído e salvo no disco.\27[0m\n\n")
        io.flush()
      else
        io.write("\27[38;5;203m ⚠️ Flush incompleto — tente novamente.\27[0m\n\n")
        io.flush()
      end
    end
  end
  io.write("\n> ")
  local input = io.read()
  if not input or input:lower() == "sair" then print("\nSaindo..."); break end
  if input == "" then goto continue end
  ui.erase_input(input)
  ui.user_msg(input)
  local _, elapsed = rodar_loop(input, "user", MAX_ITER)
  ui.footer(tokens, config.max_contexto, elapsed)
  ::continue::
end
