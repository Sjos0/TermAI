local json = require("json")
local M = {}

local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"

function M.run(old)
  local models_path = HOME .. "/.TermAI/agents/main/agent/models.json"

  local new_config = {
    meta = {
      version       = "0.1.0",
      lastTouchedAt = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
    },
    agents = {
      defaults = {
        model = {
          primary  = "openrouter/" .. old.modelo,
          fallbacks = {},
        },
        thinking       = old.reasoning ~= false,
        thinkingEffort = old.reasoning_effort or "high",
        temperature    = old.temperature or 0.7,
        maxIter        = 20,
        compaction = {
           flush_tokens             = (old.limites and old.limites.flush_tokens) or 40000,
           compactacao_pct          = (old.limites and old.limites.compactacao_pct) or 0.9,
           flush_prompt             = (old.limites and old.limites.flush_prompt) or "",
           keep_recent_tokens       = 20000,  -- REQ-1 (Walk-back por tokens)
           anchor_keep              = 5,      -- REQ-1 (Anchor de preamble)
           anchor_token_cap         = 8000,   -- REQ-1 (Anchor token cap)
           summary_max_tokens_ratio = 0.8,    -- REQ-6 (Teto dinâmico de tokens)
         },
      },
      list = {
        {
          id        = "main",
          agentDir  = "agents/main/agent",
          workspace = "workspace",
          model     = { primary = "openrouter/" .. old.modelo },
        },
      },
    },
  }

  local models_data = {
    active   = "openrouter/" .. old.modelo,
    providers = {
      openrouter = {
        baseUrl = "https://openrouter.ai/api/v1",
        apiKey  = old.api_key or "",
        api     = "openai-completions",
        models  = {
          {
            id            = old.modelo,
            name          = old.modelo,
            reasoning     = old.reasoning or false,
            input         = {"text"},
            cost          = {input=0, output=0, cacheRead=0, cacheWrite=0},
            contextWindow = old.max_contexto or 200000,
            maxTokens     = old.max_tokens or 4096,
          },
        },
      },
    },
  }

  os.execute("mkdir -p " .. HOME .. "/.TermAI/agents/main/agent")
  os.execute("cp '" .. HOME .. "/.TermAI/config.json' '" .. HOME .. "/.TermAI/config.json.bak'")

  local mf = io.open(models_path, "w")
  if mf then mf:write(json.encode(models_data)); mf:close() end

  io.write("\27[38;5;114m ✅ Configuração migrada para formato OpenClaw\27[0m\n")
  io.write("\27[38;5;245m    Backup: ~/.TermAI/config.json.bak\27[0m\n")
  io.write("\27[38;5;245m    Models: ~/.TermAI/agents/main/agent/models.json\27[0m\n\n")
  io.flush()

  return new_config
end

return M
