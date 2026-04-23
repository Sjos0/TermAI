-- memoryflush.lua — Módulo de Pré-Compactação e Controle de Contexto
-- Referência: conceito Memory Flush do OpenClaw (turno silencioso visível)

local mf = {}

-- Estado interno do módulo
local _ultimo_flush = 0   -- tokens no momento do último flush

-- ── API pública ────────────────────────────────────────────────────────────

-- Verifica se é hora de fazer um Memory Flush
-- Regra: a cada múltiplo de flush_tokens (40k, 80k, 120k...)
function mf.deve_flush(tokens, config)
  if not config.limites then return false end
  local limite = config.limites.flush_tokens or 40000
  return (tokens - _ultimo_flush) >= limite
end

-- Verifica se é hora da compactação crítica (baseada em % do contexto total)
-- Assim funciona com qualquer modelo: 262k, 1M, 2M...
function mf.deve_compactar(tokens, config)
  if not config.limites then return false end
  local pct = config.limites.compactacao_pct or 0.90
  return tokens >= (config.max_contexto * pct)
end

-- Retorna o prompt de flush (do config ou padrão robusto)
function mf.get_flush_prompt(config)
  if config.limites and config.limites.flush_prompt then
    return config.limites.flush_prompt
  end
  -- Prompt padrão detalhado caso não esteja no config
  return table.concat({
    "[SYSTEM ALARM - PRÉ-COMPACTAÇÃO] Siga rigorosamente CADA passo abaixo:",
    "1. Execute o bash `date +%Y-%m-%d` para obter a data de hoje.",
    "2. Use buscar_arquivo para verificar se existe `workspace/memory/DATA.md`",
    "   onde DATA é a data obtida no passo 1.",
    "3. Se existir: leia-o inteiro com ler_arquivo.",
    "   Se não existir: crie-o com escrever_arquivo com cabeçalho",
    "   '# Memória - DATA (DIA DA SEMANA)'.",
    "4. Faça um resumo interno do CONTEXTO ATUAL desta sessão.",
    "5. Compare com o arquivo: anote SOMENTE o que é novo,",
    "   relevante, decisões importantes ou fatos aprendidos.",
    "   Se nada for novo, não escreva nada.",
    "6. Responda EXATAMENTE: [FLUSH_DONE]",
  }, "\n")
end

-- Marca que o flush foi concluído, atualizando o rastreador
function mf.marcar_flush(tokens)
  _ultimo_flush = tokens
end

-- Retorna quantos tokens faltam para o próximo flush
function mf.proximo_flush(tokens, config)
  local limite = (config.limites and config.limites.flush_tokens) or 40000
  local ciclo_atual = math.floor((tokens - _ultimo_flush) / limite)
  return _ultimo_flush + ((ciclo_atual + 1) * limite)
end

-- Compactação simples: descarta metade mais antiga, preserva system prompt
-- Será chamada quando atingir compactacao_pct do contexto total
function mf.compactar_msgs(msgs)
  if #msgs <= 4 then return msgs end
  local nova = {msgs[1]}  -- sempre preserva o system prompt
  local inicio = math.max(2, math.floor(#msgs / 2))
  for i = inicio, #msgs do
    nova[#nova + 1] = msgs[i]
  end
  return nova
end

-- Retorna estado atual para exibição
function mf.estado(tokens, config)
  local limite = (config.limites and config.limites.flush_tokens) or 40000
  local proximo = mf.proximo_flush(tokens, config)
  return {
    ultimo  = _ultimo_flush,
    proximo = proximo,
    faltam  = proximo - tokens,
    limite  = limite,
  }
end

return mf
