# Fluxo de subagentes do ponto de vista do usuário — análise, falhas e refinamento

Status: **análise** (nenhum código alterado). Código vem por último, depois que o fluxo estiver aprovado.
Regra de análise: todo recurso novo do TermAI passa por esta revisão antes do código (ver seção 7).

## 1. Fluxo de ponta a ponta

Exemplo: o usuário digita "usa um subagente para pesquisar X enquanto eu continuo".

| # | O que acontece (backend) | O que o usuário vê na TUI |
|---|---|---|
| 1 | O pai (orquestrador) recebe o pedido e decide chamar `sessions_spawn`. | Linha de tool do pai: `⬤ sessions_spawn …` (card da chamada). |
| 2 | `spawn.spawn` grava o run (`queued` ou `running`) e sobe o processo `TermAI run --worker`. Devolve JSON `accepted` com `runId`. | O card da tool mostra o resultado (`accepted`, `runId`). |
| 3 | O pai responde ao usuário ("subagente iniciado…") e o turno termina. | Texto da resposta do pai. |
| 4 | Com a TUI ociosa, o `on_idle` roda a cada 2 s: `scheduler.tick` promove runs da fila, detecta mortes e timeouts. | Linha amarela `⬤ Subagente <id> · lançado pelo orquestrador · <tarefa>`. Aparece só agora, depois do turno. |
| 5 | O filho roda em processo próprio: `context.build`, loop, `snapshot` do último texto útil, `events.jsonl`. | Nada. Não há progresso visível (só via `/subagents` ou `subagents_info`). |
| 6 | O filho termina: `worker` grava `result.txt` e status (`completed`, `failed` com classe do erro, `timeout` com parcial). | Nada ainda, a não ser que a TUI esteja ociosa. |
| 7 | No próximo tick ocioso, `has_pending` vira verdadeiro e o `on_idle` retorna `wake`. | `↻ subagentes concluídos` aparece **como se o usuário tivesse digitado**. |
| 8 | Um turno de sistema é disparado: `[sistema] Os subagentes terminaram…`. `announce.inject` põe o resultado no contexto do pai e imprime a linha verde. | Linha verde `⬤ Subagente <id> · concluído · resultado entregue ao orquestrador`, depois a resposta do pai. |
| 9 | O pai responde com o resultado. O fluxo termina. | Resposta do pai. Não há link para o resultado bruto na TUI. |

Se o usuário estiver digitando no passo 7, o aviso espera o campo esvaziar (correto). Se o pai estiver num turno longo, o aviso espera o turno acabar (correto).

## 2. Falhas encontradas

| ID | Falha | Evidência (código) | Impacto para o usuário | Severidade |
|---|---|---|---|---|
| F1 | Um lançamento aparece **duas vezes**: card da tool (`accepted`) e linha amarela. | `spawn.lua` devolve `accepted`; `ui/subagent_block` imprime a amarela. | Poluição; a mesma ação em dois lugares. | Média |
| F2 | A linha amarela só aparece **quando o pai fica ocioso**. Durante um turno longo, o subagente nasce sem feedback. | `on_idle` só roda na espera de input. | Usuário não sabe se o subagente foi criado. | Alta |
| F3 | `↻ subagentes concluídos` aparece como **linha de digitação** do usuário. | `main_loop.lua`: `input = "↻ subagentes concluídos"`. | Parece que o usuário digitou algo. Confusão. | Alta |
| F4 | **Um turno de modelo por filho** que termina. Três filhos em sequência geram três avisos e três turnos. | `has_pending` é por run; não há janela de agrupamento. | Custo, latência e ruído (screenshots mostraram vários avisos seguidos). | Alta |
| F5 | A linha amarela diz **"lançado"** mesmo quando o run está `queued` (fila cheia, 5 simultâneos). | `subagent_block.pending_lines` usa o mesmo texto para `running` e `queued`. | Mensagem enganosa: o usuário acha que já está rodando. | Média |
| F6 | **Sem progresso na TUI.** O usuário não sabe se o filho está trabalhando ou travado. | Só `/subagents` e `subagents_info` mostram estado, e só sob demanda. | Ansiedade e pergunta repetida ao pai. | Média |
| F7 | Ao **sair da TUI**, filhos de nível 0 continuam rodando sem dono visível; o cascade só cobre filhos aninhados (`parent_run`). | `scheduler.lua`: `cascade_orphans` só trata `parent_run`. | Processos e custo fora do controle do usuário. | Média |
| F8 | **Ctrl+C no turno do pai não toca nos filhos.** Não há pergunta nem atalho para parar um subagente pela TUI. | Sem ligação entre interrupção e `subagents_kill`. | Usuário acha que parou tudo e não parou. | Alta |
| F9 | **Na reabertura da TUI**, resultados de filhos que terminaram enquanto ela estava fechada não são anunciados de forma explícita. O baseline marca runs existentes como vistos. | `subagent_block.baseline` marca tudo como visto. | Resultado "some" da visão do usuário, embora o pai ainda o entregue depois. | Média |
| F10 | **O resultado não aparece na TUI.** A linha verde diz "resultado entregue", mas o usuário só vê o texto que o modelo escreveu. | `end_line` não mostra prévia. | Não dá para conferir o que o filho realmente produziu. | Baixa |
| F11 | **Largura de terminal estreita (Termux).** Linhas longas quebram e ocupam muitas linhas; com vários filhos a tela enche. | Linhas da TUI sem limite de largura. | Poluição visual no celular. | Média |

## 3. Fluxo refinado (proposta)

Princípios: append-only (sem `ESC[nA`, porque no Termux a quebra de linha quebra o redesenho), uma ação = uma linha, sem simulação de digitação, e o aviso acorda o pai no momento certo.

| # | Mudança | Resolve |
|---|---|---|
| R1 | A linha amarela sai **no momento do lançamento real**, dentro do fluxo do turno (não no próximo ocioso). E só aparece quando o run está de fato `running`. Se estiver na fila, a linha diz `na fila (3/5)`. | F1, F2, F5 |
| R2 | O card da tool do pai passa a mostrar só o essencial (`runId`, `status`). A linha amarela vira o único aviso visual do lançamento. | F1 |
| R3 | **Agrupamento de avisos:** quando o primeiro filho termina, espera até 5 s (ou até o pai ficar ocioso) e junta os que terminarem nesse intervalo. Um único turno de sistema por lote. | F4 |
| R4 | O aviso de lote aparece como **linha de sistema**, nunca como linha de usuário: `── 2 subagentes concluídos ──`. | F3 |
| R5 | `/subagents` vira o painel sob demanda: lista com status, tempo decorrido, tools usadas e último evento. Não é redesenhado sozinho. | F6 |
| R6 | **Ctrl+C no turno do pai** pergunta uma vez: `Parar também os 2 subagentes ativos? (s/N)`. Padrão: não. Se confirmar, chama o mesmo caminho de `subagents_kill`. | F8 |
| R7 | Ao **sair** da TUI com filhos ativos, mostra uma linha: `2 subagentes continuam rodando; os resultados chegam na próxima sessão.` | F7 |
| R8 | Ao **reabrir**, mostra os que terminaram enquanto estava fora, em um lote: `── enquanto você esteve fora: 1 subagente concluído (sub-x) ──`. | F9 |
| R9 | A linha verde traz uma prévia curta do resultado (até 80 colunas, uma linha). O texto completo fica em `/subagents info <id>`. | F10 |
| R10 | Todas as linhas de subagente são truncadas em uma linha lógica (largura da tela) e nunca quebram o prompt. | F11 |

## 4. Como fica na TUI (mockups, texto puro)

Sequência normal, usuário ocioso:

```
> pesquisa X num subagente enquanto eu continuo
  ⬤ sessions_spawn  accepted  runId=sub-6ada4a80e1a2
Ok, lancei o subagente sub-6ada4a80e1a2 para pesquisar X.
  ⬤ Subagente sub-6ada4a80e1a2 · rodando · pesquisar X
> _
  ── 1 subagente concluído ──
  ⬤ Subagente sub-6ada4a80e1a2 · concluído · "X tem três fontes principais…"
Resumindo o que o subagente trouxe: …
> _
```

Fila cheia (5 simultâneos, sexto pedido):

```
  ⬤ Subagente sub-6ada4a80e1a2 · na fila (1/1) · pesquisar Y
```

Falha com classe do erro:

```
  ✗ Subagente sub-6ada4a80e1a2 · falhou · network: Sem resposta do servidor
```

Ctrl+C no meio do turno do pai:

```
^C
Parar também os 2 subagentes ativos? (s/N) _
```

Reabrindo a TUI:

```
> _
  ── enquanto você esteve fora: 1 subagente concluído (sub-6ada4a80e1a2) ──
```

Regras de largura: cada linha de subagente cabe em uma linha lógica da tela (cortada com `…`). Nada de caixas, bordas ou painéis, porque isso quebra no Termux.

## 5. Comparação com o OpenClaw

Fonte: documentação oficial da TUI em docs.openclaw.ai/web/tui (lida nesta análise).

| Aspecto | OpenClaw (documentado) | TermAI hoje | Decisão |
|---|---|---|---|
| Cabeçalho | URL, agente e sessão atuais | Nada parecido | Adotar uma linha de estado curta |
| Ação de tool | Um **card por chamada**, atualizado no lugar enquanto a tool roda | Card da tool + linha amarela (duplicado, F1) | Adotar o card único; no Termux, sem redesenho (append-only) |
| Streaming | Atualiza a resposta no lugar | Stream em linha | Manter |
| Histórico | Carrega as últimas 200 mensagens ao conectar | Histórico da sessão ao abrir | Já existe; manter |
| Comandos | `/status`, `/deliver`, seletor de modelo e de agente | `/subagents`, `/config`, etc. | Acrescentar `/status` (estado do pai e dos filhos) |
| Interrupção | Ctrl+C cancela o turno | Ctrl+C cancela o turno, sem falar dos filhos | Adotar a pergunta do R6 |
| Subagentes na TUI | Não encontrei seção dedicada a subagentes na documentação da TUI | Linhas próprias | Nosso diferencial: documentar isso como decisão nossa |

O que copiar: o card único por ação e o `/status`. O que não copiar: atualização no lugar, porque o nosso terminal (Termux) quebra linha e o redesenho deixa resíduo (já registrado no código).

## 6. Cenários de teste (o que testar antes de codar, e depois)

Cada cenário tem o resultado esperado. Os de TUI são manuais no celular até existir um harness; os de backend viram specs.

| ID | Cenário | Resultado esperado |
|---|---|---|
| S1 | Um subagente, pai ocioso | Uma linha amarela, uma linha verde com prévia, uma resposta do pai. |
| S2 | Subagente lançado durante um turno longo do pai | Linha amarela aparece assim que o run está `running`, sem esperar o turno acabar (R1). |
| S3 | Filho termina enquanto o usuário digita | Nada é impresso no meio da digitação; o aviso sai depois do Enter (R3). |
| S4 | Três filhos terminam em 3 s | Um lote, um turno do pai, uma linha de lote (R3, R4). |
| S5 | Sexto pedido com 5 rodando | Linha diz `na fila (n/5)`, nunca `lançado` (R1, F5). |
| S6 | Filho falha por rede | Linha vermelha com classe do erro (já existe; checar largura). |
| S7 | Filho estoura o prazo | Linha com `timed out` e prévia do parcial (R9). |
| S8 | Ctrl+C durante turno do pai com filho ativo | Pergunta (s/N); `N` mantém os filhos; `s` encerra todos (R6). |
| S9 | Sair da TUI com filho ativo, reabrir depois | Linha ao sair (R7); lote de "enquanto você esteve fora" ao reabrir (R8). |
| S10 | Termux em 40 colunas | Nenhuma linha passa da largura; nada quebra o prompt (R10). |
| S11 | `TermAI run --wait-subagents` | Saída com resultados e código 0; timeout com código 3 (já coberto por spec). |
| S12 | Filho aninhado (profundidade 2) termina antes do pai | Aviso vai ao pai aninhado, não ao usuário (já coberto por spec). |
| S13 | `/subagents` com 0, 1 e 6 runs | Tabela legível em 40 colunas; sem cortar o prompt (R5). |
| S14 | Linha de sistema do lote | Nunca aparece com cara de digitação do usuário (R4). |

## 7. Regra permanente para qualquer recurso novo do TermAI

Antes de codar, todo recurso novo passa por estas perguntas, nesta ordem:

1. **Quem usa e em que momento?** Descrever o fluxo do usuário passo a passo, como na seção 1.
2. **O que ele vê em cada passo?** Escrever a tela, como na seção 4, em 40 colunas.
3. **Onde pode falhar?** Procurar falhas no fluxo (como na seção 2), incluindo: fechar a TUI, Ctrl+C, digitar no meio, fila cheia, falha de rede, terminal estreito.
4. **Como o OpenClaw faz?** Pesquisar na documentação oficial e comparar (como na seção 5).
5. **Quais cenários de teste?** Listar antes do código (como na seção 6).
6. **Só então o código.** E o código não pode quebrar a TUI nem poluir a tela.

## 8. Ordem sugerida

1. Aprovar este fluxo (você decide quais R1 a R10 entram).
2. Implementar primeiro F3 e F4 (ruído e custo), que são as mais visíveis e baratas.
3. Depois F1, F2 e F5 (lançamento honesto), com S1, S2 e S5.
4. Depois F8 e F7 (Ctrl+C e saída), com S8 e S9.
5. Por último F6, F10, F11 (painel e largura), com S10, S13.
