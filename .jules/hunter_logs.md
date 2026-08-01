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
