-- tests/minimax_m3_reasoning_spec.lua — Issue #136: payload de reasoning do MiniMax M3 (NVIDIA).
-- O M3 exige chat_template_kwargs = { thinking_mode = "enabled" } (string); os outros
-- modelos com reasoning_style = "chat_template_kwargs" continuam com { thinking = true }.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local json = require("json")
local payload = require("agent.api.payload")
local harness = require("tests.helpers.harness")
local T = harness.T

-- Monta o payload real com reasoning ativo e devolve a tabela decodificada.
local function payload_de(style, model_id)
  local ctx = {
    msgs = {},
    cfg = { agents = { defaults = { temperature = 0.5, maxIter = 5 } } },
    active = {
      model_id = model_id, context_window = 65536, max_tokens = 1024,
      reasoning = true, reasoning_style = style,
    },
  }
  local raw = payload.build_payload(ctx, "oi", "user", true)
  local ok, dec = pcall(json.decode, raw)
  return ok and dec or nil
end

-- Procura o modelo no catálogo do provider (estrutura recursiva, sem depender do formato exato).
local function achar_modelo(t, id, visto)
  visto = visto or {}
  if type(t) ~= "table" or visto[t] then return nil end
  visto[t] = true
  if t.id == id then return t end
  for _, v in pairs(t) do
    local r = achar_modelo(v, id, visto)
    if r then return r end
  end
  return nil
end

print("\n=== Issue #136: reasoning do MiniMax M3 (NVIDIA) ===")

local p_m3 = payload_de("chat_template_thinking_mode", "minimaxai/minimax-m3")
T("M3: chat_template_kwargs.thinking_mode = 'enabled'",
  p_m3 and p_m3.chat_template_kwargs and p_m3.chat_template_kwargs.thinking_mode == "enabled")
T("M3: não envia o campo booleano thinking",
  p_m3 and p_m3.chat_template_kwargs and p_m3.chat_template_kwargs.thinking == nil)

local p_nem = payload_de("chat_template_kwargs", "nvidia/nemotron")
T("Nemotron (chat_template_kwargs): continua com thinking = true",
  p_nem and p_nem.chat_template_kwargs and p_nem.chat_template_kwargs.thinking == true)
T("Nemotron: não ganha thinking_mode",
  p_nem and p_nem.chat_template_kwargs and p_nem.chat_template_kwargs.thinking_mode == nil)

local ok_prov, prov = pcall(require, "providers.nvidia")
local m3 = ok_prov and achar_modelo(prov, "minimaxai/minimax-m3") or nil
T("catálogo NVIDIA: minimax-m3 usa reasoning_style = chat_template_thinking_mode",
  m3 ~= nil and m3.reasoning_style == "chat_template_thinking_mode")
local m25 = ok_prov and achar_modelo(prov, "minimaxai/minimax-m2.5") or nil
T("catálogo NVIDIA: minimax-m2.5 (que já funciona) encontrado e mantém chat_template_kwargs",
  m25 ~= nil and m25.reasoning_style == "chat_template_kwargs")

print(string.format("\nRESULTADO (minimax m3 reasoning): %d passaram, %d falharam", harness.pass, harness.fail))
if harness.fail > 0 then os.exit(1) end
