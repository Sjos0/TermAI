# Análise da issue #176: fundo nos cards, streaming parcial e status line

Base: origin/main 5b752d6. Branch: feat/tui-cards-bg-stream-status.

## 1. Verificação das afirmações da spec

| # | Afirmação da spec | Resultado | Evidência |
|---|---|---|---|
| A1 | Cards não têm fundo próprio | VERDADEIRO | `ui/tools_init/default_body.lua` escreve prefixo e texto sem `c.bg`. `ui/tools_init/edit_renderer.lua` tem 8 pontos de `io.write` sem fundo (linhas 27, 98, 107, 115, 117, 119, 122, 132). |
| A2 | Paleta de fundo já existe (`c.bg` = 48;5;234) | VERDADEIRO | `ui/core.lua` linha 13: `bg="\27[48;5;234m"`, `bg_user="\27[48;5;236m"`. |
| A3 | `card.cut` existe e corta por colunas UTF-8 | VERDADEIRO | `ui/card.lua` linhas 11-19. Função pura. |
| A4 | Output da tool só aparece no `tool_end` | VERDADEIRO | `executor.lua` `tool_start` escreve só o cabeçalho. O corpo sai em `tool_end` com `out` completo. |
| A5 | Streaming parcial "exige caminho incremental" entre tool_start e tool_end | VERDADEIRO, mas INCOMPLETO | O `out` vem de `tools.call(...)` (`agent/tools_handler/executor.lua`, e o equivalente em `agent/loop/tool_runner`), uma chamada síncrona que devolve a string inteira. Não existe callback de saída parcial em `tools` nem nos runners. Logo, P2 não é só UI: exige mudança na camada de execução das tools (ex.: callback `on_chunk` no Exec e no Subagente). |
| A6 | Não há status line hoje | PARCIALMENTE FALSO | Existe um spinner de uma linha, feito por um processo `sh` em `ui/spinner/roteiros.lua`, com rótulos "Injetando", "Requisitando" e "Pensando" e contador de segundos. Ele roda em background e escreve com `\r`. O que não existe é o rótulo "Trabalhando". |
| A7 | "Requisitando" é trocado em `update_label` | PARCIALMENTE FALSO | `ui/spinner/compact.lua` `update_label` só chama `launch.set_inject_flag()`. A troca de rótulo acontece dentro do script `sh` (`roteiros.lua`), quando o arquivo `ta_inject.flag` aparece. |
| A8 | Animação de gradiente amarelo (220) → laranja | NÃO EXISTE | O código tem cor fixa: `LB` = 255;193;7 (amarelo) e `YELLOW` = 220. Não há gradiente. Gradiente é trabalho novo. |
| A9 | Animação de gradiente reaproveita `compact.lua` | PARCIAL | Quem anima é o script `sh`, não `compact.lua`. Reaproveitar significa mexer em `roteiros.lua`. |
| A10 | Fundo deve ser aplicado em `default_body.lua` e `edit_renderer.lua` | VERDADEIRO | São os dois renderizadores de corpo de card. |
| A11 | Existe teste de card (`tests/tui_cards_spec.lua`) | VERDADEIRO | Testes existentes checam largura e rótulo. Nenhum checa fundo. Padrão: `lua5.4 tests/<nome>_spec.lua`, saída "ALL OK". |
| A12 | Ler `core.tw()` e `core.cp_width` antes de decidir | VERDADEIRO | `core.tw()` é usado em todos os renderizadores. |

## 2. Riscos encontrados

- R1 (P1). Preencher a linha com espaços sob o fundo pode causar quebra automática quando a linha ocupa exatamente `tw` colunas. Solução: preencher até `tw - 1`, como o restante do código já faz para não encostar na borda.
- R2 (P1). Aplicar `c.bg` sem `c.reset` no fim da linha vaza a cor para a linha seguinte. Toda linha de card deve terminar com `c.reset`.
- R3 (P1). Terminal sem 256 cores: `48;5;234` é ignorado ou vira cor errada. A spec pede degradação; o código atual já usa `38;5;...` sem fallback, então o comportamento seria o mesmo.
- R4 (P2). Mudar `tools.call` para streaming toca em tools de longa duração (Exec, Subagente). Pode quebrar contrato com o modelo se o `out` final mudar. Precisa de teste de regressão do resultado final.
- R5 (P2). Repintar um card já escrito exige subir o cursor com `ESC[nA`. As regras do projeto proíbem redesenho com `ESC[nA` em conteúdo que pode quebrar linha. Streaming precisa ser append-only ou limitado a uma linha de progresso que é apagada no fim.
- R6 (P3). Um segundo spinner/status line na mesma tela colide com o spinner `sh` existente. Só pode existir um escritor da linha de status. Precisa decidir se a status line substitui o spinner ou vira seu novo rótulo.
- R7 (P3). Regra do projeto: a linha de status não pode poluir a tela nem ser redesenhada com `ESC[nA`. Gradiente por caractere gera muitas sequências de cor a cada 0,1 s. Em Termux isso pode piscar.
- R8. Os itens F2 (linha amarela só no ocioso) e F3 (rótulo de sistema parece digitação), listados na análise anterior do TermAI, tocam a mesma área da status line. Devem ser resolvidos juntos ou explicitamente adiados.

## 3. Plano proposto

Fase P1 (menor risco, pronta para implementar):
1. Criar em `ui/card.lua` um helper `M.bg_row(text_colored, tw)` que aplica `c.bg`, preenche até `tw - 1` e fecha com `c.reset`. Função pura, testável.
2. Usar o helper em `default_body.lua` e nos 8 pontos de `edit_renderer.lua`.
3. Teste novo `tests/tui_card_bg_spec.lua` com mutação: remover o `c.bg` deve fazer o teste falhar; restaurar depois.
4. Rodar `tests/tui_cards_spec.lua` e a suíte inteira de tests, conforme a regra de processo 3.

Fase P2 (precisa de decisão do usuário): callback `on_chunk` na execução de tool; linha de progresso única, append-only, apagada no `tool_end`.

Fase P3 (precisa de decisão do usuário): onde mora a status line (substituir o spinner `sh` ou manter e trocar só o rótulo); gradiente só se for leve (ex.: alternar entre 2 cores, não por caractere).

## 4. Perguntas em aberto

- Q1. P2: aceita mudar a camada `tools.call` para aceitar callback de saída parcial, ou prefere streaming só para Exec?
- Q2. P3: a status line substitui o spinner `sh` atual ou convive com ele?
- Q3. P3: o gradiente pode ser apenas alternância entre dois tons (amarelo 220 e laranja), em vez de degradê por caractere?
