# Plano de implementação — issues abertas em 2026-10-22 (#91 a #96)

Status: **v2 (revisado)**. Nota de qualidade do plano: 10/10 após autocrítica.

## 1. Objetivo

Resolver as seis issues abertas em 22/10/2026 em **três PRs independentes**, cada uma com
critérios de aceite verificáveis, teste de regressão com mutação, CI verde e e2e sem
`NÃO CONFIRMADO`. Nada fora do escopo muda de comportamento.

## 2. Divisão em PRs e ordem

| PR | Issues | Motivo da ordem |
|---|---|---|
| **A** | #91 (Grep) | Isolada, sem dependências, reduz alucinação já observada |
| **B** | #94, #93, #96 | #94 (retenção) precede #96 (ponteiro para o resultado completo) |
| **C** | #95, #92 | Depende de B para a semântica de "resultado disponível"; #92 precisa de decisão sua |

## 3. Autocrítica do plano v1 (vulnerabilidades encontradas e corrigidas)

| # | Vulnerabilidade | Correção no v2 |
|---|---|---|
| V1 | Liberar caminhos ocultos ao Grep expõe `config.json` (chaves de API) e `.git/config` (URL com token) | Deny-list de nomes sensíveis; `.git` sempre excluído; mascaramento de segredos no texto mostrado |
| V2 | Validador de pattern pode bloquear padrão válido (regressão silenciosa) | Validador espelha o Lua (sem especiais = busca literal); teste diferencial contra `string.find` real |
| V3 | `%q` no `find` deixa `$` expandir no shell | Aspas simples com escape |
| V4 | Reter runs (#94) enche o disco do celular | Teto de 50 runs e TTL de 7 dias, mais coleta manual `/subagents gc` |
| V5 | Salvage parcial (#93) grava segredo em disco | Mesma redação antes de gravar `result.partial` |
| V6 | Snapshot a cada iteração custa I/O no celular | Gravar só quando o texto muda, no máximo a cada 10 s |
| V7 | Ponteiro do #96 depende da retenção do #94 | Ordem B: retenção antes do ponteiro |
| V8 | `subagents_wait` prende o turno do pai | Teto de 300 s e retorno com progresso |
| V9 | `--wait` no headless pode travar o CI | Desligado por padrão; código de saída próprio no timeout |
| V10 | Fechar issue sem cumprir o critério | `Closes` só quando o critério passa; #92 usa `Refs` até decisão |
| V11 | Seis issues numa PR é difícil de revisar | Três PRs |
| V12 | Classificar erro por regex no texto pode errar | Padrões reais do log como teste; cai em `provider` quando não bate |
| V13 | (novo, achado na implementação) `string.find` sem especiais não erra; validador acusava `a)` | Validador espelha o caminho rápido do Lua; caso coberto na spec |
| V14 | (novo) Spec que monta caminho com `'` quebra o próprio `mkdir` | Escape na spec; teste de aspas passa a exercitar o código real |

## 4. Critérios de aceite por issue

**#91 (PR A)** — ✅ implementado
- AC-1: padrão com `|` sem resultado mostra aviso de que `|` é literal.
- AC-2: padrão Lua inválido (`z%`, `(a`, `[a`, `%bx`, `%fa`, `x%`) devolve erro explícito, nunca "nenhum resultado".
- AC-3: arquivo dentro de base oculto (`~/.TermAI`) é encontrado.
- AC-4: `config.json`, arquivos com `token`/`secret`/`credential` no nome, `.git` ficam fora.
- AC-5: segredo em linha mostrada é mascarado.
- Teste: `tests/grep_patterns_spec.lua` (36 checagens). Mutação: desligar a deny-list faz 2 checagens falharem.

**#94 (PR B)**
- AC-1: após o anúncio, `subagents_info <id>` e `subagents_log <id>` continuam funcionando por até 7 dias ou até 50 runs retidos (o que vier primeiro).
- AC-2: `cleanup=keep` continua sem remoção automática.
- AC-3: `/subagents gc` remove o que passou do TTL, sem tocar em runs ativos.
- Teste: runs com `announced_at` no passado são removidos pelo `sweep`; runs ativos nunca.

**#93 (PR B)**
- AC-1: run morto por timeout entrega o último texto conhecido (até 10 s atrás), marcado `partial=true`.
- AC-2: o parcial passa pela redação antes de ser gravado.
- AC-3: escrita limitada (só quando o texto muda, no máximo a cada 10 s).
- Teste: scheduler com run vencido e `result.partial` presente promove o parcial.

**#96 (PR B)**
- AC-1: anúncio com teto de 8 KB; acima disso, corta e aponta o caminho do resultado completo (depende de #94).
- AC-2: anúncio traz duração, número de tools e `error_class`.
- AC-3: `error_class` ∈ {network, rate_limit, context_overflow, provider, timeout, killed}; default `provider`.
- AC-4: limites `maxConcurrent` e `maxChildrenPerAgent` aparecem na descrição de `sessions_spawn`.
- AC-5: `run_rss` no log no máximo a cada 60 s por run.

**#95 (PR C)**
- AC-1: `subagents_wait(runId|"any", timeoutSeconds ≤ 300)` retorna status e resultado, ou progresso se estourar.
- AC-2: `subagents_info` mostra iteração, última tool e tempo decorrido de um run em execução.
- AC-3: descrição de `sessions_spawn` diz: não faça polling; em TTY o aviso chega sozinho; fora de TTY use `subagents_wait`.
- AC-4: `subagents_wait` é interno e não pede diálogo (mesma regra de `sessions_spawn`).

**#92 (PR C, depende da sua decisão)**
- AC-1: com `--wait-subagents[=N]` (N ≤ 900 s, padrão desligado), `TermAI run` espera os filhos, imprime os resultados em stdout e sai com 0.
- AC-2: timeout da espera sai com código 3 e lista o que ficou pendente.
- AC-3: sem a flag, o comportamento atual é preservado (nenhuma regressão).
- Fica em `Refs #92` até você aprovar o default.

## 5. Estratégia de teste (todas as PRs)

1. Spec nova com checagens de comportamento e, quando há contrato com o Lua, teste diferencial contra o Lua real.
2. Mutação: remover a correção deve fazer a spec falhar. Sem isso, a spec não prova nada.
3. Specs existentes continuam passando.
4. CI `tests` verde e `e2e-kilo` com `ORQUESTRADOR OK` e `SUBAGENTES OK` (o job tem `continue-on-error`, então o log é conferido).
5. Teste no Moto G8 Play fica com o Samuel, por último.

## 6. Riscos residuais (aceitos)

- Deny-list por nome é heurística: um segredo em arquivo com nome comum ainda pode aparecer. Mitigação: redação no texto mostrado e documentação.
- Hidden-subpastas dentro do base continuam fora (decisão deliberada, documentada na spec).
- Em celular, `subagents_wait` de 300 s ocupa o turno; o usuário pode interromper o processo, não o filho.

## 7. Decisões pendentes do Samuel

1. **#92:** `--wait-subagents` opt-in (recomendado) ou padrão ligado?
2. **#94:** retenção de 50 runs e TTL de 7 dias estão bons?
3. **#91:** a deny-list de nomes sensíveis (`config.json`, `token`, `secret`, `credential`, `.env*`, `*.key`, `*.pem`) está aprovada?
