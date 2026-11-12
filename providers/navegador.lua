-- providers/navegador.lua — IA do site, via ponte local do Termavigator.
-- O Termavigator expõe uma API compatível com chat completions em 127.0.0.1 e leva
-- as mensagens ao chat do site. Sem streaming e sem campos de raciocínio.
-- A chave pedida aqui é o token de pareamento mostrado no Termavigator
-- (Modo desenvolvedor > Copiar token). Não é chave de nenhum modelo.
return {
  id = "navegador",
  name = "Navegador (IA do site)",
  baseUrl = "http://127.0.0.1:8787/v1",
  api = "termai-navegador",
  needs_key = true,
  key_hint = "token de pareamento (Termavigator > Modo desenvolvedor > Copiar token)",
  docs = "https://github.com/Sjos0/Termavigator",
  models = {
    {
      id = "ia-do-site",
      name = "IA do site",
      reasoning = false,
      input = {"text"},
      cost = {input=0, output=0, cacheRead=0, cacheWrite=0},
      contextWindow = 32000,
      maxTokens = 4096,
    },
  },
}
