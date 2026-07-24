-- agent/api/summarizer/runner.lua — Orquestrador do fluxo assíncrono de chamada à API de resumo.
local json       = require("json")
local utils      = require("agent.api.utils")
local ui_mod     = require("agent.api.summarizer.ui")
local serializer = require("agent.api.summarizer.serializer")
local validator  = require("agent.api.summarizer.validator")

local M = {}

function M.summarizar(active, cfg, mensagens, on_attempt, ctx)
  if #mensagens == 0 then return nil, "Nenhuma mensagem para resumir." end

  local serialized_history = serializer.serialize_messages(mensagens)

  local messages = {
    { role = "system", content = validator.system_prompt },
    { role = "user",   content = "Condense o histórico de operações agênticas abaixo:\n\n" .. serialized_history },
  }

  local payload = { model = active.model_id, messages = messages, temperature = 0.2, max_tokens = 4096 }
  local pl      = json.encode(payload)
  local auth    = utils.build_auth(active)
  local rcfg    = utils.get_req_cfg({cfg=cfg, active=active})

  local last_fallback = nil

  for attempt = 1, rcfg.max_retries do
    local tmp_path = utils.make_tmp_path()
    local tmp = io.open(tmp_path, "w")
    tmp:write(pl); tmp:close()

    local out_path = utils.make_tmp_path() .. "_res.json"

    -- Roda o curl em background com & (Garante não-bloqueio para a animação do rodapé)
    local cmd = string.format(
      'curl -s --max-time %d --speed-time %d --speed-limit 1 -X POST "%s"%s -H "Content-Type: application/json" -d @%s > %s 2>/dev/null &',
      rcfg.timeout, rcfg.idle_timeout, active.endpoint, auth, tmp_path, out_path)

    os.execute(cmd)

    -- Loop de Polling Assíncrono com Animação Vermelha (comp...) na TUI
    local start_t = ui_mod.get_wall_time()
    local animation_states = { "(comp.)", "(comp..)", "(comp...)" }
    local anim_idx = 1
    local completed = false
    local response_content = nil

    local current_tokens = ctx and ctx.tokens or 35000
    local context_window = active.context_window or 1000000

    while ui_mod.get_wall_time() - start_t < rcfg.timeout do
      os.execute("sleep 0.25")
      local elapsed = math.floor(ui_mod.get_wall_time() - start_t)

      -- Atualiza o frame da animação em vermelho
      local anim = animation_states[anim_idx]
      anim_idx = (anim_idx % #animation_states) + 1
      ui_mod.render_red_footer(current_tokens, context_window, elapsed, anim)

      -- Verifica se o arquivo de output terminou de ser escrito com JSON íntegro
      local f = io.open(out_path, "r")
      if f then
        local content = f:read("*a")
        f:close()
        if content and (content:match("choices") or content:match("error")) then
          completed = true
          response_content = content
          break
        end
      end
    end

    -- Limpa a linha de status do rodapé temporário de comp
    io.write("\r\27[K")
    io.flush()

    -- Limpa os arquivos temporários criados
    os.remove(tmp_path)
    os.remove(out_path)

    if completed and response_content then
      local ok, rep = pcall(json.decode, response_content)
      if ok and rep and rep.choices and rep.choices[1] then
        local content = rep.choices[1].message.content
        if content and content ~= "" then
          local stripped = utils.strip_thinking_tags(content)

          if validator.is_valid_summary(stripped) then
            return stripped
          else
            last_fallback = stripped
            io.write("\27[38;5;245m     ⚠️  Resumo gerado fora do padrão estrutural (tentativa " .. attempt .. "). Re-tentando...\27[0m\n")
            io.flush()
          end
        end
      end
    end

    if attempt < rcfg.max_retries then
      os.execute(string.format("sleep %d", utils.wait_time(attempt, rcfg)))
    end
  end

  if last_fallback then
    io.write("\27[38;5;220m     ⚠️  Aviso: Não foi possível obter um resumo 100% estruturado após várias tentativas. Usando melhor versão disponível.\27[0m\n")
    io.flush()
    return last_fallback
  end

  return nil, "O servidor não conseguiu processar a condensação após várias tentativas."
end

return M
