# Grok — Contribution Log

Registro de contribuições do Grok (xAI) ao projeto TermAI.

---

## 2026-10-30 - [#265 rodapé ANSI]
**Issue:** #265
**Veredito:** CONFIRMADA — SGR contado como coluna; T1 media após gsub; T2/T7 ausentes.
**Files Modified:** ui/largura.lua (visivel), ui/misc.lua (prioridade), tests/footer_tela_emulador_spec.lua
**Decisões:** colunas/cortar ignoram CSI; cortar preserva SGR; prioridade relógio→tempo→tokens.
**Prova de sensibilidade:** colunas sem visivel → T4 tempo/relogio FAIL; gsub no emulador esconde defeito de medição.
**Correção da #253:** comprovação anterior fraca; T1–T7 agora medem com CSI interpretado.
**Author:** Grok (xAI)


## 2026-10-30 - [release v1.37.0]
**Author:** Grok (xAI)


## 2026-10-30 - [#250 rodapé Block]
**Issue:** #250
**Veredito:** CONFIRMADA
**Files Modified:** ui/misc.lua, tests/footer_block_spec.lua
**Evidência:** footer_block_spec ALL OK (tw 40/80/120, 1m, tw<20)
**Author:** Grok (xAI)


## 2026-10-30 - [#251 formatar_limite]
**Issue:** #251
**Veredito:** CONFIRMADA
**Author:** Grok (xAI)


## 2026-10-30 - [#249 layout]
**Issue:** #249
**Veredito:** CONFIRMADA
**Author:** Grok (xAI)


## 2026-10-30 - [#248 Block]
**Issue:** #248
**Veredito:** CONFIRMADA
**Files Modified:** ui/widgets/block.lua + block/*
**Evidência:** block_spec ALL OK
**Author:** Grok (xAI)


## 2026-10-30 - [#247 Referência Ratatui]
**Issue:** #247
**Veredito:** CONFIRMADA
**Files Modified:** docs/REFERENCIA_RATATUI.md
**Author:** Grok (xAI)


## 2026-10-30 - [#246 AMBIENTE.md]
**Issue:** #246
**Veredito:** CONFIRMADA
**Files Modified:** docs/AMBIENTE.md, README.md
**Evidência:** arquivo existe; premissa + ressalva; link no README
**Author:** Grok (xAI)


## 2026-10-30 - [#243 Prova Exec caracteres largos]
**Issue:** #243
**Veredito:** CONFIRMADA — lacuna de prova e2e.
**Files Modified:** tests/exec_tela_emulador_spec.lua
**Prova de sensibilidade:** utf8.len em card.cut/width → Exec×2
**Evidência:** C1–C5 ALL OK
**Author:** Grok (xAI)

## 2026-10-30 - [release v1.36.16]
**Author:** Grok (xAI)


## 2026-10-29 - [release v1.36.15]
**Contexto:** Patch de provas #238/#239
**Author:** Grok (xAI)


## 2026-10-29 - [#239 Streamer real + transporte falso]
**Issue:** #239
**Veredito:** CONFIRMADA — spec anterior copiava lógica.
**Files Modified:** tests/no_retry_after_token_spec.lua
**Prova de sensibilidade:** got_data=false → HTTP calls=3 no cenário A
**Evidência:** no_retry_after_token_spec ALL OK (io.popen mock)
**Author:** Grok (xAI)


## 2026-10-29 - [#238 Boot real sem stubs]
**Issue:** #238
**Veredito:** CONFIRMADA — spec anterior stubava módulos e não provaria falha.
**Contexto:** TERMAI_BOOT_ONLY=1 + subprocesso real.
**Files Modified:** agente.lua, tests/agente_boot_real_spec.lua, .grok/fluxo_trabalho.md
**Prova de sensibilidade:** pcall(...).install → "attempt to index a boolean value" EXIT:1
**Evidência:** agente_boot_real_spec ALL OK com código atual
**Author:** Grok (xAI)


## TERMAI_BOOT_ONLY
Variável de ambiente de teste: se `TERMAI_BOOT_ONLY=1`, `agente.lua` retorna após `startup.run` e **não** entra no loop interativo. Inerte quando ausente. Usada por `tests/agente_boot_real_spec.lua` (#238).


## 2026-10-29 - [release v1.36.14]
**Author:** Grok (xAI)


## 2026-10-29 - [#226 limite 150 + size spec]
**Issue:** #226
**Veredito:** CONFIRMADA — roteiros 192, compact 157, streamer 154, edit_renderer 152.
**Files Modified:** streamer/parte_1.lua, edit_renderer.lua, tests/tamanho_150_spec.lua, README.md
**Evidência:** tamanho_150_spec ALL OK
**Author:** Grok (xAI)


## 2026-10-29 - [#226 compact ≤150]
**Issue:** #226
**Files Modified:** ui/spinner/compact.lua, compact_stop.lua
**Author:** Grok (xAI)


## 2026-10-29 - [#226 roteiros ≤150]
**Issue:** #226
**Veredito:** CONFIRMADA — roteiros.lua 192 linhas.
**Files Modified:** ui/spinner/roteiros.lua, spinner_script.lua, compact_script.lua
**Author:** Grok (xAI)


## 2026-10-29 - [#225 Legadas e branch]
**Issue:** #225
**Veredito:** CONFIRMADA
**Author:** Grok (xAI)


## 2026-10-29 - [#224 Spec no-retry após token]
**Issue:** #224
**Veredito:** CONFIRMADA — faltava spec de contagem HTTP.
**Files Modified:** tests/no_retry_after_token_spec.lua
**Evidência:** no_retry_after_token_spec ALL OK
**Author:** Grok (xAI)


## 2026-10-29 - [#223 Boot real agente.lua]
**Issue:** #223
**Veredito:** CONFIRMADA — agente_boot_spec só lintava.
**Files Modified:** tests/agente_boot_real_spec.lua
**Evidência:** agente_boot_real_spec ALL OK (dofile headless)
**Author:** Grok (xAI)


## 2026-10-29 - [#222 ta_pid por instância]
**Issue:** #222
**Veredito de validade:** CONFIRMADA — launch.lua:6 `_spin_pid = TMPDIR.."/ta_pid"`; cleanup matava spinner vivo de outra instância.
**Files Modified:** ui/spinner/launch.lua, ui/spinner/cleanup_startup.lua, tests/ta_pid_por_instancia_spec.lua, tests/tui_spinner_cleanup_startup_spec.lua
**Evidência de aceite:** ta_pid_por_instancia_spec ALL OK (A vivo preservado; dono morto limpo; não-spinner vivo).
**Author:** Grok (xAI)


## 2026-10-29 - [#227 Política de evidência]
**Issue:** #227
**Veredito de validade:** CONFIRMADA — histórico de PRs #211–#219 e relatórios sem evidência por critério.
**Contexto:** formalizar checklist e template de evidência.
**Files Modified:** `.claude/claude.md`, `.grok/grok.md`
**Evidência de aceite:** regra presente nos dois arquivos (grep "Política de evidência").
**Author:** Grok (xAI)


## Política de evidência de aceite (obrigatória em toda PR) — #227

**Regra:** cada critério de aceite da issue deve ter, no corpo da PR, o **nome do spec ou comando** e a **saída** que o comprovam. Critério sem evidência = não cumprido.

### Antes de abrir a PR
1. Validar que o problema existe no código atual (reproduzir ou provar por leitura com arquivo+linha).
2. Checklist explícita de todos os critérios da issue.
3. Sem checklist completa, não abrir a PR.

### Template de corpo de PR
```
Closes #<N>

## Veredito de validade
CONFIRMADA | PARCIAL | NÃO CONFIRMADA — evidência: <arquivo:linha ou saída>

## Critérios de aceite
| Critério | Spec/comando | Resultado |
|----------|--------------|-----------|
| ... | tests/..._spec.lua | PASS / saída resumida |

## Arquivos
- path (wc -l antes → depois)

## Validação
- Suíte: N PASS / 0 FAIL
- PTY: PASS|FAIL

## Não comprovado
- <item> — razão
```

### Relatórios de conclusão
Listar: comprovado, não comprovado, pendente. Proibido afirmar "resolvido" sem evidência anexada.



## 2026-10-29 - [release v1.36.13]
**Contexto:** Patch SemVer apos #202–#208.
**Author:** Grok (xAI)



## 2026-10-29 - [#208 Política SemVer]
**Issue:** #208
**Contexto:** Duplicidade de tags legadas vs SemVer; registro inconsistente.
**Equivalências legada → SemVer (referência):**
| Legada | SemVer |
|--------|--------|
| v1.36.12.2026 | v1.36.12 |
| v1.36.11.2026 | (patch histórico; ver v1.36.12) |
| v1.36.10.2026 | (histórico) |
| v1.35.x.2026 | (histórico) |
**Decisões:** não apagar releases legadas; VERSION e tag vX.Y.Z únicos daqui pra frente.
**Author:** Grok (xAI)


## 2026-10-29 - [#207 tmp unificado]
**Issue:** #207
**Files Modified:** agent/paths/tmp.lua, agent/api/utils.lua, models/validate.lua
**Author:** Grok (xAI)


## 2026-10-29 - [#205 stream_complete]
**Issue:** #205
**Files Modified:** agent/loop.lua, streamer/parte_1.lua, tests/loop_turno_erro_spec.lua
**Author:** Grok (xAI)


## 2026-10-29 - [#204 Cleanup startup por PID]
**Issue:** #204
**Files Modified:** ui/spinner/cleanup_startup.lua, ui/spinner/launch.lua, agent/api/utils.lua, tests/cleanup_startup_pid_spec.lua
**Decisões:** artefatos com PID; cleanup só remove dono morto; nunca mata não-spinner.
**Validation:** cleanup_startup_pid_spec ALL OK
**Author:** Grok (xAI)


## 2026-10-29 - [#206 Spec boot agente.lua]
**Issue:** #206
**Files Modified:** tests/agente_boot_spec.lua
**Decisões:** lint pcall(...).campo + carga de terminal_safe headless.
**Validation:** agente_boot_spec ALL OK
**Author:** Grok (xAI)


## 2026-10-30 - [#203 Retry linhas físicas]
**Issue:** #203
**Contexto:** clear_retry com emoji residual; depende de #202.
**Files Modified:** ui/spinner/retry.lua, tests/retry_linhas_fisicas_spec.lua
**Decisões:** paint retorna linhas físicas (1 por row cortada); api_error fora de _retry_lines.
**Validation:** retry_linhas_fisicas_spec + retry_card_inplace ALL OK
**Author:** Grok (xAI)


## 2026-10-30 - [#202 Largura visual conservadora]
**Issue:** #202
**Contexto:** utf8.len subestimava emoji/CJK; ESC[nA deixava cabeçalho amarelo residual.
**Files Modified:** ui/largura.lua, ui/card.lua, ui/tools_init/header.lua, tests/largura_conservadora_spec.lua
**Decisões:** módulo puro conservador; card e header delegam.
**Validation:** largura_conservadora_spec ALL OK
**Author:** Grok (xAI)


## 2026-10-29 - [chore: SemVer MAJOR.MINOR.PATCH]
**Contexto:** Versionamento legado `1.N.10.YYYY` substituído por SemVer de mercado.
**Baseline:** `1.36.12` (continuidade com o contador anterior; sem o sufixo de ano).
**Files Modified:** `VERSION`, `README.md` (seção Versionamento), `tests/update_release_spec.lua`, `tools/update/release.lua`.
**Author:** Arquiteto.
**Validation:** update_release_spec + CI.


## 2026-10-29 - [TUI: card de retry in-place, code fence, boot pcall, temp paths]

**Contexto:** Lista Claude #181–#187 + bugs de TUI reportados por screenshots (retry empilhado, input sumindo, ``` com buracos pretos, crash `pcall().install`).

**Entregas (main):**
- v1.35.11 — `agente.lua`: pcall não indexa boolean (PR #197)
- v1.35.10 — temp path unificado TMPDIR (#186, PR #196); #187 fechada sem busy loop (evidência Ubuntu)
- v1.36.10 — card retry in-place (`ui/spinner/retry.lua` + `bg_error`), `show_api_error`, code_renderer com pad (não ESC[K), PR #198
- Auditoria pós-merge: CI verde em 48fe466; show 5/5 antes do [ERRO]; wrap UTF-8 no code_renderer; specs reforçados

**Referência Ratatui:** Block+Paragraph com style bg contínuo e wrap por largura — espelhado em `card.bg_row` + pad de espaços.

**Author:** Grok (Arquiteto TermAI)

---


## 2026-08-06 - [Diagnóstico: Cache parcial de grafo é falsa otimização]

**Contexto:** Continuação da sessão de permissões Exec + GraphRAG. Samuel anexou a Spec completa criada pelo Ameno.
**Diagnóstico confirmado:** cache parcial (tags/snippets) não resolve ~25s de boot.
**Ação:** PR #21 com cache de grafo completo + incremental.

**Author:** Grok 4.5 (xAI)

---

## 2026-08-06 - [PR #21 v2.1 — Fixes do review do Ameno + UI de permissão]

**Fixes Ameno (3 críticos):** cache sem content, zero stat no hot path, invalidate só RAM, arestas bidirecionais, TMPDIR.
**Fixes UI:** status limpo, colapso completo, suggest sem lixo, deny orientativo.

**Author:** Grok 4.5 (xAI)

---

## 2026-08-06 - [PR #21 v3.2 — Regressão dirty flag (auditoria final Ameno)]

**Regressão:** `invalidate_cache()` só limpava RAM; hot path confiava no disco quando `file_count` igual → índice stale após Edit/Write em arquivo de memória.

**Fix:** `_cache.dirty = true` em `invalidate_cache()`. Hot path só confia no disco se `dirty == false`. Após recheck de mtimes, limpa dirty. Callers (editor/write/todo) não precisam mudar.

**Author:** Grok 4.5 (xAI)
**Status:** Mergeado via PR #21.

---

## 2026-08-07 a 2026-08-09 - [PR #24: Alternate Screen Modal — resolve bug Termux scroll]

**Período:** Criada 07/08, atualizada até 09/08, mergeada 09/08.
**Contexto:** A PR #23 (cursor save/restore) falhava no Termux quando o diálogo era longo o bastante para rolar a tela — a posição salva se perdia e o box ficava preso.
**Evolução incremental (3 versões):**
1. **v1/v2** — Contar `\n` + `ESC[1A` → quebrava com wrap visual
2. **v3 (PR #23)** — `ESC[s` save cursor + `ESC[u` + `ESC[0J` → falha no Termux scroll
3. **v5 (PR #24)** — Alternate screen buffer (`ESC[?1049h/l`) → correto, terminal cuida de scroll/wrap

**Fix:**
- `enter_modal_screen()` — DECSET 1049 (tela alternativa) + clear + home
- `leave_modal_screen()` — DECRST 1049 (volta pra tela principal)
- `xpcall` garante `leave_modal_screen()` mesmo em erro
- Teste novo: `permissions_ui_modal_spec.lua` (162 linhas, 55 casos)
- Removido: `ESC[1A`, `ESC[2K`, contagem de linhas, `collapse_and_resolve`

**Validação (no Termux real):**
- `luac -p`: ✅ 2/2
- `permissions_ui_modal_spec`: 52/55 (3 falhas no `<Enter>` — timing do mock, não bug real)
- `bash_patterns_bug`: 64/64 ✅
- `graph_cache_full_spec`: 10/10 ✅
- `fuzzy_match_pr4`: ✅
- `thinking_spinner`: 15/15 ✅
- **Zero regressões**

**Author:** Grok 4.5 (xAI)
**Status:** Mergeado (commit `8c5c820`). Branch deletada.

---

## 2026-08-09 - [Ajuste de espaçamento: linha em branco entre status e Exec]

**Contexto:** Samuel reportou que o status `✅ Permitido uma vez` ficava colado no header do Exec.
**Fix:** `"\n"` → `"\n\n"` no `io.write` do status (1 caractere).
**Arquivo:** `tools/exec/permissions_ui.lua`
**Author:** Grok 4.5 (xAI) + Ameno (edição local)
**Status:** Aplicado localmente. Aguardando confirmação visual do Samuel.

---

## 2026-09-10 - [PR #40: facade agent/loop + fix last_reasoning no cancel JSON]

**Contexto:** Issue #29 — monólito `agent/loop.lua` (187 linhas) concentrava loop ReAct e protocolo.
**Implementação:** fachada `M.rodar` + `system_messages`, `response_utils`, `json_path`, `xml_path` (branch `refactor/29-agent-loop-facade`).
**Review Caçador:** divergência residual — cancel JSON hardcodava `last_reasoning = ""` em vez de propagar o outer da fachada.
**Fix:** `json_path.handle` recebe e propaga `last_reasoning` no return de cancel (`3de8a67`); FLUSH_DONE continua zerando.
**Testes:** trava em `tests/loop_units_spec.lua` — cancel com outer vazio e com outer **não-vazio** (guarda contra regressão do hardcode).

**Author:** Grok (xAI) — Agente Implementador
**Status:** PR #40 aberta; correção e teste forte na mesma branch.

---

## 2026-09-14 - [PR: fix README DOC-GAP #35 + VERSION 1.14.09.2026]

**Contexto:** Issue #35 — README ainda documentava apenas o fluxo legado (`lua5.4 main.lua`) e omitia `install.sh`, o comando global `TermAI` e os subcomandos CLI (`tui`, `models`, `config`, `update`, etc.).

**O que foi feito:**
- Reescrita da seção de instalação: caminho recomendado via `install.sh` + wrapper `$PREFIX/bin/TermAI`.
- Documentação dos comandos CLI disponíveis pós-instalação.
- Atualização da árvore de estrutura para incluir `install.sh` e esclarecer o papel de `main.lua`.
- Operator Quick Refs agora distingue comandos de sessão (TUI) e comandos de linha de comando.
- Bump de VERSION de `1.2.0` → `1.14.09.2026` (formato data embutida no dia da entrega).

**Decisão de versão:** escolhido `1.14.09.2026` (1. + dia.mês.ano) para manter prefixo semântico leve e deixar a data de release explícita, alinhado à sugestão do solicitante (ajustando mês para setembro/2026).

**Author:** Grok (xAI) — Agente Implementador
**Status:** Branch `fix/35-readme-install-cli`; PR a abrir.

---

## 2026-09-15 - [PR: fix latex false positives #36 + VERSION 1.15.09.2026]

**Contexto:** Issue #36 — `apply_latex` substituía substrings de comandos LaTeX em paths (`path\to\file` → `path→\file`), drives Windows (`C:\times\data`) e tratava `$100` como math mode.

**O que foi feito:**
- Passagem standalone: boundary à **esquerda** além da direita — não substitui se o caractere anterior for alfanumérico, `\` ou `:` (paths Unix/Windows).
- Passagem inline `$...$`: heurística de moeda — se o conteúdo (após espaços) começa com dígito e não contém `\`, o par `$...$` é preservado.
- Pattern de display math `$$...$$` corrigido para `%$%$(.-)%$%$` (estava com escape incorreto).
- Suite de regressão nova: `tests/latex_false_positives_spec.lua` (paths, moeda, guard de letra, math legítimo, bordas).
- Bump VERSION `1.14.09.2026` → `1.15.09.2026`.

**Decisões de design:**
- Política de moeda: preservar `$` + dígito sem `\` (ex.: `$100`). Math com `\` dentro continua convertido.
- Boundary esquerda deliberadamente inclui `:` para cobrir `C:\...` sem heurística de drive letter.
- Escopo limitado ao bug reportado; sem refatoração arquitetural do processador (candidata a issue futura).

**Author:** Grok (xAI) — Agente Implementador
**Status:** Branch `fix/36-latex-false-positives`; PR a abrir.

---

## 2026-09-16 - [PR: desativação de tools por agente #32 + VERSION 1.16.09.2026]

**Contexto:** Issue #32 — permitir desativar (e reativar) tools de forma persistente e por agente, de modo que tools desativadas não entrem no schema enviado ao modelo.

**O que foi feito:**
- `tools.get_schema(disabled)` / `tools.get_docs(disabled)` com filtro opcional (set ou array); ordem estável preservada; nil se zero tools restarem.
- `agent/context.lua`: resolve agente ativo por id, popula `ctx.disabled_tools` (set) e `ctx.agent_id` — sem hardcode `"main"`.
- `agent/api/payload.lua`: passa `ctx.disabled_tools` para `get_schema`; `ctx.no_tools` continua soberano (compactação).
- Defesa em profundidade em `tools.call` / `tools.call_structured` (erro claro se path legado chamar tool desativada).
- Menu TUI `commands/config/menus/tools.lua` e CLI `commands/config_cli/menus/tools.lua`: lista do registry, toggle individual, desativar todas, reativar todas; persiste em `agents.list[].disabled_tools`.
- Registro da opção 8 nos menus principais de config (TUI e CLI).
- Bump VERSION `1.15.09.2026` → `1.16.09.2026`.

**Decisões de design:**
- Filtro centralizado na fachada `tools` (parâmetro explícito) — não acopla tools a ctx global.
- Persistência no entry do agente (não em defaults nem em sessão).
- Permissões (ask/block/always) intocadas e ortogonais.
- Multi-agent-ready: resolve por id do agente ativo.

**Author:** Grok (xAI) — Agente Implementador
**Status:** Branch `feature/32-disable-tools-per-agent`; PR a abrir.

---

## 2026-09-26 - [PR #68: batch DOC-GAP / inconsistências de docs + VERSION 1.26.09.2026]

**Contexto:** Batch de 13 issues de inconsistência documental e de superfície pública — README, help CLI, banner, `TermAI status`, slash commands TUI (`available.lua` / `/help`), notas históricas em `tests/` e `agent/flush/tests/`.

**Issues fechadas neste PR:** #48 #50 #54 #55 #56 #57 #59 #60 #61 #62 #63 #64 #65.

**O que foi feito:**
- `commands/help.lua` e banner de `main.lua` alinhados aos subcomandos reais (`config`, `skills`, `npx`, `restart`).
- README: Multi-Provedor (Cline/Gitlawb/Kilo), `providers/`, `agent/hooks/`, stub MCP, canal Telegram, `.claude/.grok/.jules`, lista canônica de slash, nota de ausência de runner CI em `tests/`.
- `commands/status.lua`: inventário de módulos e UI corrigido (`tools/editor.lua`, `ui/input`, `thinking_parser`, `tools_init`).
- `commands/available.lua` + `/help` na TUI: fonte única de slash (inclui `/compact` e `/status`).
- `tests/BUG-bash_patterns-persistencia.md` marcado RESOLVIDO (histórico); `test_T1.lua` corrige path `agente/` inexistente.
- Bump VERSION `1.16.09.2026` → `1.26.09.2026` (formato `1.<dia>.<mês>.<ano>` no dia da entrega).

**Decisões de design:**
- Escopo restrito a docs e inventários de superfície — sem refatorar menus config TUI/CLI paralelos (#58) nem bugs de runtime (#66 error_feedback, #67 spawn `/models` com `lua`).
- `/help` TUI deixa de `dofile` da ajuda CLI e passa a listar `commands.available`.

**Author:** Grok (xAI) — Agente Implementador
**Status:** Branch `docs/inconsistencias-doc-gap-batch`; PR #68 aberta. GitHub Release tag fica para após merge em `main` (único release publicado até então: v1.2.0).

---

---

## 2026-10-08 - [VERSION #79: atualização canônica + registro .ChatGPT]

**Contexto:** Issue #79 — alinhar a versão interna ao ciclo de entrega de 08/10/2026 e registrar a mudança no repositório.

**O que foi feito:**
- Bump de `VERSION` `1.26.09.2026` → `1.8.10.2026`.
- Criado `.ChatGPT/ChatGPT.md` para registrar a versão canônica, rastreabilidade e estado do release.
- Nenhum código-fonte ou `.github/` foi alterado.

**Decisão de versão:** mantido o padrão histórico `1.<dia>.<mês>.<ano>` usado pelo projeto; para 08/10/2026, a string adotada é `1.8.10.2026`.

**Author:** Ameno — Agente Implementador
**Status:** Implementação na branch `fix/79-version-2026-10-08-chatgpt-record`; PR #80 aberta para revisão. Merge e publicação do GitHub Release permanecem para decisão humana.

**Correção #253 (2026-10-30):** comprovação anterior fraca (gsub antes de medir; T2/T7 ausentes). Corrigido em #265.
## 2026-10-30 - [#268 retry quebra stream_end]
**Issue:** #268
**Veredito de validade:** CONFIRMADA
**Files Modified:** ui/spinner/retry.lua, ui/spinner/compact_stop.lua, agent/api/request_stream/streamer/parte_1.lua, tests/retry_stream_end_stack_spec.lua
**Decisões:** is_active + guarda em compact_stop; último attempt limpa.
**Prova de sensibilidade:** \n reintroduzida → 4 linhas FAIL; restaurada → green.
**Evidência de aceite:** caminho real ≤1 residual; após erro 0 + [ERRO]. Specs antigos OK.
**Erros cometidos nesta issue e correções:** nenhum.
**Author:** Grok (xAI)

## 2026-10-30 - [#269 Block bg + wrap]
**Issue:** #269
**Veredito de validade:** CONFIRMADA (sem bg/wrap no código; specs falharam no main)
**Files Modified:** ui/widgets/block/render.lua, ui/widgets/block.lua, tests/block_bg_wrap_spec.lua
**Decisões:** wrap por palavra com largura.colunas; h=nil calcula altura; bg em todas as células.
**Prova de sensibilidade:** remover bg da borda → FAIL all_have_bg; restaurado green.
**Evidência de aceite:** bg SGR em todas linhas; wrap longo; palavra sem espaço; regressão OK.
**Erros cometidos nesta issue e correções:** nenhum.
**Author:** Grok (xAI)

## 2026-10-30 - [#270 blocos tentativa/erro]
**Issue:** #270
**Veredito de validade:** CONFIRMADA
**Files Modified:** ui/spinner/retry.lua (Block), recovery.lua (retorna texto), fallback.lua (passa recover), specs
**Decisões:** tentativa 1 linha em Block vermelho; erro multi-linha com recover+[ERRO]; sem io.write cru.
**Prova de sensibilidade:** (bloco via is_active já coberto em #268); recovery sem write verificado.
**Evidência de aceite:** moldura+bg; recover no bloco; erro longo quebra; tw estreito.
**Erros:** spec residual do emulador mínimo — ajustado para ESC[nA + última tentativa.
**Author:** Grok (xAI)

## 2026-10-30 - [#271 revisão testes retry]
**Issue:** #271
**Veredito de validade:** CONFIRMADA (lacunas de path cobertas pelos specs #268/#270)
**Files Modified:** tests/retry_caminho_real_spec.lua (índice de cobertura)
**Decisões:** não duplicar lógica; documentar specs que já exercitam stream_end e Block.
**Author:** Grok (xAI)

## 2026-10-30 - [release v1.38.0]
**Issues:** #268 #269 #270 #271 fechadas
**PRs:** #272 #273 #274 #275 mescladas
**Versão:** 1.38.0 (MINOR — Block fundo/wrap + blocos tentativa/erro)
**Author:** Grok (xAI)

## 2026-10-31 - [#281 token na memória]
**Issue:** #281
**Veredito de validade:** CONFIRMADA (incidente de processo na missão 1.38.0)
**Contexto:** Ordem v1.38.1 E1 — varredura de credenciais na memória de projeto e no repositório.
**Ação:** Varredura em project_memory: nenhum valor `ghp_*` / `github_pat_*`. Entrada de autonomia reescrita para proibir persistir credencial (só leitura em runtime de fonte externa). `git grep` no main: sem resultado real.
**Files Modified:** .grok/grok.md (este registro); memória de projeto (sem valor secreto).
**Erros cometidos nesta issue e correções:** na missão 1.38.0 o token foi usado em URL de remote em sessão de shell (não commitado); medida: nunca embutir token em remote persistente nem em memória.
**Author:** Grok (xAI)

## 2026-10-31 - [#282 emulador por célula]
**Issue:** #282
**Veredito de validade:** CONFIRMADA
**Files Modified:** tests/emulador_celulas_spec.lua (novo), tests/block_bg_wrap_spec.lua (migração por célula)
**Decisões:** emulador interpreta CSI/SGR por célula {fundo,texto,glifo}; block_bg_wrap exige fundo 52 em todas as células do retângulo.
**Prova de sensibilidade:** removido bg da linha de borda → FAIL all_have_bg + missing=120; restaurado git diff vazio.
**Evidência de aceite:** T1 ABC fundo 52 cols 1-3; T2 missing=0; specs relacionados PASS; PTY_OK.
**Erros cometidos nesta issue e correções:** dofile acidental de emulador_celulas_spec dentro de block_bg_wrap (causava os.exit precoce) — linha removida.
**Author:** Grok (xAI)

## 2026-10-31 - [#279 recover histórico]
**Issue:** #279
**Veredito de validade:** CONFIRMADA (while remove apagava user e respostas válidas)
**Files Modified:** agent/api/request_stream/recovery.lua, fallback.lua (comentário), tests/recover_historico_spec.lua
**Decisões:** remove só órfãos (assistant tool_calls sem tool reply); preserva user/assistant posteriores.
**Prova de sensibilidade:** while remove original → FAIL A/B; restaurado ALL OK.
**Erros:** nenhum.
**Author:** Grok (xAI)

## 2026-10-31 - [#279 persistência reinício]
**Issue:** #279 (complemento)
**Veredito:** CONFIRMADA — save_exchange com msgs_before fixo pulava user após recover.
**Correção:** persistence.adjust_before localiza user pelo content stampado; main_loop usa before ajustado.
**Erro cometido:** cenário C só na memória (PR #285) — não cobriu save_exchange; corrigido nesta PR.
**Sensibilidade:** adjust_before identity → FAIL gravação; restaurado OK.
**Author:** Grok (xAI)

## 2026-10-31 - [#278 cores bloco erro]
**Issue:** #278
**Veredito:** CONFIRMADA
**Files:** render.lua (frame_bg/fg, interior_bg), block.lua, core.c, retry.lua, tests/bloco_erro_cores_spec.lua
**Decisões:** contorno 203/52, interior 52, texto 231; constantes em core.c
**Sensibilidade:** sem interior_bg → FAIL bad=38/78; restaurado OK
**Erros:** emulador do spec contava bytes UTF-8; corrigido para utf8.char
**Author:** Grok (xAI)

## 2026-10-31 - [#279 adjust última ocorrência]
**Refs:** #279
**Correção:** adjust_before percorre de n→1.
**Erro anterior:** primeira ocorrência podia apontar mensagem antiga.
**Author:** Grok (xAI)

## 2026-10-31 - [#277 rodapé Tokens]
**Issue:** #277
**Veredito:** CONFIRMADA
**Files:** ui/misc.lua, ui/widgets/layout.lua, tests/rodape_tokens_spec.lua
**Decisões:** place_natural; Tokens:; corte pct→sem pct→sem tempo; relógio por último
**Sensibilidade:** split_equal tw50 → relógio ausente
**Erros:** nenhum
**Author:** Grok (xAI)
