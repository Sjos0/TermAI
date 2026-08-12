# Forensic Debugging Log — Hunter Persona 🐛

## Debug Report

> **Bug:** Quando o usuário realiza qualquer ação de confirmação no menu de configuração de modelos ou provedores, o prompt de confirmação/pausa ("Pressione Enter para continuar...") aparece DUAS vezes, e o usuário precisa pressionar Enter DUAS vezes para sair daquela tela.
>
> **Root Cause:** Chamada redundante de `ui.pause()` tanto nas funções controladoras de sub-ação individuais canto no loop do menu principal em `commands/models/menu.lua`. O menu principal já possui a responsabilidade de pausar e limpar a tela a cada ciclo, mas certas sub-ações também invocavam `ui.pause()` no seu encerramento.
>
> **Evidence:**
> - `commands/models/menu.lua` possui chamadas a `ui.pause()` para as opções 3 (add model), 6 (add provider), 7 (remove provider) e 8 (update key).
> - As sub-ações correspondentes nos seguintes arquivos também continham chamadas internas a `ui.pause()`:
>   - `commands/models/models/add.lua` (linha 88)
>   - `commands/models/providers/add.lua` (linha 110)
>   - `commands/models/providers/remove.lua` (linha 37)
>   - `commands/models/providers/update_key.lua` (linha 47)
> - Outras opções do menu, como listagem e info, que não continham `ui.pause()` interno, funcionavam corretamente com apenas uma pausa.
>
> **Falsification:**
> - **Hypothesis:** O problema é decorrente de buffering de input no terminal ou caracteres `\n` remanescentes em raw mode.
>   - *Falsification:* Se fosse buffering de input, as opções de listagem (1) e detalhes (5) também pulariam ou apresentariam comportamento anômalo. No entanto, elas funcionavam perfeitamente com exatamente 1 pressionamento de tecla. Logo, a hipótese de buffering foi descartada em favor de chamadas explícitas redundantes no código.
>
> **Patch:**
> - Remover a linha de chamada `ui.pause()` dos arquivos:
>   - `commands/models/models/add.lua`
>   - `commands/models/providers/add.lua`
>   - `commands/models/providers/remove.lua`
>   - `commands/models/providers/update_key.lua`
> - Causal justification: Retirar o `ui.pause()` das sub-ações de folha delega a responsabilidade de controle do fluxo interativo de pausa e limpeza de tela exclusivamente ao menu chamador (`menu.lua`), que é o padrão de arquitetura correto do harness.
>
> **Validation:**
> - Criação do teste de asserção estática `tests/test_config_pauses.lua` que varre o conteúdo limpo dos arquivos de sub-ação e confirma a ausência de chamadas a `ui.pause()`.
> - Verificação direta do fluxo por meio de inspeção cuidadosa do diff e da execução da suíte de testes.

## Lessons Learned
- **Separação de Responsabilidades de UI:** Componentes de baixo nível / sub-ações não devem assumir como ou quando a tela será pausada ou limpa. Essa responsabilidade pertence ao gerenciador de fluxo de alto nível (o menu).
- **Consistência:** Sub-ações como `set.lua` e `remove.lua` (de modelos) já seguiam esse padrão corretamente. O desvio nas outras sub-ações introduziu o bug.

---

## 2026-08-12 - [Memory Flush/Edit Diff Inexistente na TUI]
> **Bug:** Quando o Memory Flush faz um Edit em arquivo de memória, o TUI mostra apenas "Substituição concluída ✓" sem mostrar o diff (linhas adicionadas/removidas). O usuário não vê o que foi escrito.
> **Root Cause:**
> 1. No arquivo `tools/editor/result_builder.lua`, a função `should_diff` rejeitava mensagens de sucesso do Edit que possuíam caracteres acentuados, como `"Substituição aplicada"`, permitindo apenas o formato sem acento (`"Substituicao aplicada"`) ou em inglês (`"Replacement applied"`). Como as mensagens retornadas nos testes e em certas configurações eram acentuadas, a verificação falhava e o diff não era gerado.
> 2. No arquivo `tools/editor/diff_builder.lua`, a função `build` falhava em tratar `before_content` como vazio e falhava em abortar o diff quando o texto antigo (`old_text`) não era localizado. O diff falhava e não gerava as métricas corretas.
> **Evidence:**
> - A suíte de testes `tests/edit_diff_display_spec.lua` reportava originalmente 10 falhas isolando precisamente estes comportamentos no `diff_builder` (Caso 2, Caso 4) e no `result_builder` (Result 1, Result 3, Pipeline).
> - Após as correções, todos os 37 testes passaram sem erros.
> **Patch:**
> - Atualizado `should_diff` em `tools/editor/result_builder.lua` para realizar match tanto de `"Substituicao aplicada"`, `"Substituição aplicada"`, quanto `"Replacement applied"`.
> - Atualizado `build` em `tools/editor/diff_builder.lua` para lidar com `before_content == ""` retornando `nil, nil, nil`, e para retornar `nil, 0, 0` em buscas por texto exato quando `pos` (posição do texto antigo) for `nil`.
> - Ajustado o cálculo de `is_zero_change` no `result_builder.lua` para evitar falsos positivos quando `before_content` não é fornecido.
> - Melhorado o `diff_builder` para tratar patches com `old == new` como contexto comum, sem computar adições/remoções fantasmas.
> **Lesson:** Sempre valide os caminhos de internacionalização/acentuação e trate com rigor as condições de contorno de arquivos/conteúdos nulos ou vazios no fluxo de exibição de diffs.
