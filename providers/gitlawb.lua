local M = {}

M.id        = "gitlawb"
M.name      = "OpenGateway (Gitlawb)"
M.baseUrl   = "https://opengateway.gitlawb.com/v1"
M.api       = "openai-completions"
M.needs_key = true
M.docs      = "https://gitlawb.com/opengateway"
M.key_hint  = "Chave gratuita em: gitlawb.com/opengateway/dashboard (login com X)"

M.models = {
  {
    id              = "mimo-v2.5-pro",
    name            = "Mimo v2.5 Pro",
    contextWindow   = 1000000,
    maxTokens       = 32768,
    reasoning       = true,
    reasoning_style = "thinking_tags",
    input           = {"text"},
    cost            = {input = 0, output = 0, cacheRead = 0, cacheWrite = 0},
  },
}

return M
