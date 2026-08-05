# 🔬 Relatório de Análise de Bug — Edit tool reports success when no changes were made

> **Status:** Análise Concluída ✓
> **Persona:** Hunter 🐛
> **Data:** 2026-08-04

---

## 1. Descrição do Bug
Ao reexibir (replay) ou executar um comando da ferramenta `Edit` em que nenhuma alteração real de conteúdo foi realizada no arquivo (por exemplo, quando a edição já havia sido aplicada anteriormente), a interface do TermAI exibe incorretamente as mensagens:
```
⬤ Edit (caminho/do/arquivo)
 │ └ Adicionadas 0 linha(s), removida(s) 0 linha(s)
 └─ Substituição concluída ✓
```
Em vez de celebrar um sucesso inexistente ("Substituição concluída ✓"), a interface deveria indicar claramente que nenhuma alteração foi feita ou que a substituição falhou/não foi aplicada, refletindo a realidade sem mensagens enganosas.

---

## 2. Localização Exata no Código

O comportamento indesejado é causado pela interação de dois arquivos de frontend/orquestração de interface:

1. **`ui/tools_init/edit_renderer.lua`**
   - **Localização:** Linhas 9-23
   - **Trecho de código:**
     ```lua
     function M.render_edit_body(lines, ok, tw)
       local added, removed = 0, 0
       local metrics_idx = nil

       -- 1. Varredura de busca de métricas na string
       for idx, ln in ipairs(lines) do
         local a, r = ln:match("^METRICS:%s*added=(%d+),%s*removed=(%d+)")
         if a and r then
           added, removed = tonumber(a), tonumber(r)
           metrics_idx = idx
           break
         end
       end

       -- 2. Imprime resumo de alterações no topo da box
       local prefix = " │ "
       if added and removed then
         local summary = string.format("Adicionadas %d linha(s), removida(s) %d linha(s)", added, removed)
     ```

2. **`ui/tools_init/executor.lua`**
   - **Localização:** Linhas 46-59 (função `M.tool_replay`)
   - **Trecho de código:**
     ```lua
     function M.tool_replay(cmd, out, ok)
       local tw        = core.tw()
       local name, arg = parser.parse_cmd(cmd)
       if out then
         ...
       end
       header.write_header(ok and c.green or c.red, name, arg)
       render_result_body(name, out, ok, tw)
       io.write("\n"); io.flush()
     end
     ```

---

## 3. Causa Raiz

### Fator Causal A (Defaulting enganoso de métricas)
No arquivo `ui/tools_init/edit_renderer.lua`, as variáveis locais `added` e `removed` são inicializadas com `0`.
Se a saída (`out`) da ferramenta `Edit` não possuir a linha `METRICS: added=X, removed=Y` (o que ocorre quando o diff sequer é computado porque a edição já foi previamente aplicada), a varredura não encontrará nada, mantendo `added = 0` e `removed = 0`.
Como em Lua os números (inclusive `0`) são avaliados como verdadeiros (`truthy`), a condição `if added and removed then` é satisfeita e a interface exibe `"Adicionadas 0 linha(s), removida(s) 0 linha(s)"` no topo, mesmo sem qualquer alteração associada.

### Fator Causal B (Ausência de validação em Replays)
No arquivo `ui/tools_init/executor.lua`, ao final da execução normal de uma ferramenta, a função `M.tool_end` calcula `actual_ok` usando o parser unificado:
```lua
local actual_ok = parser.is_edit_success(out, ok)
```
No entanto, na função `M.tool_replay` (usada ao recarregar o histórico de uma sessão), o valor de `ok` é repassado diretamente para `render_result_body`, sem passar pela validação de `parser.is_edit_success`. Assim, se o histórico de comandos gravou a execução com `ok = true` (por exemplo, porque a ferramenta retornou status ok com aviso ou porque não foi tratada como falha estrita no fluxo legado de persistência), o replay renderizará o rodapé como `"Substituição concluída ✓"`.

---

## 4. Falsificação / Verificação das Hipóteses
- **Hipótese 1: É o motor de edição que falha e não calcula as métricas.**
  - *Falsificação:* Incorreto. O motor de edição em `tools/editor/result_builder.lua` calcula corretamente `is_zero_change`. No entanto, quando a edição já está aplicada, o motor retorna `true, "Edicao ja aplicada [1/1]"`, o que intencionalmente não gera diff (logo, sem métricas). O bug ocorre porque a camada de visualização exibe `0` linhas em vez de ocultar o resumo de alterações, e exibe sucesso em replays sem consistência.
- **Hipótese 2: O rodapé "Substituição concluída ✓" é hardcoded para sempre ser verde.**
  - *Falsificação:* Parcialmente correto. Ele depende do parâmetro `ok` recebido pela função `render_edit_body`. Na execução em tempo real (`tool_end`), `actual_ok` resolve corretamente para `false` se houver métricas zero. Mas no replay (`tool_replay`), `ok` é repassado sem filtragem, ignorando as métricas.

---

## 5. Sugestão de Correção (Plan de Correção Mínimo)

Para corrigir definitivamente o problema mantendo a integridade e sem refatorações desnecessárias, outro agente deve aplicar as seguintes duas correções mínimas:

### Correção 1: Inicialização nula de métricas em `ui/tools_init/edit_renderer.lua`
Modificar a inicialização de `added` e `removed` para `nil` para que o resumo no topo da box só seja exibido se a linha `METRICS` correspondente for de fato encontrada no output da ferramenta.

**Substituição sugerida em `ui/tools_init/edit_renderer.lua`:**
```lua
<<<<<<< SEARCH
function M.render_edit_body(lines, ok, tw)
  local added, removed = 0, 0
  local metrics_idx = nil

  -- 1. Varredura de busca de métricas na string
  for idx, ln in ipairs(lines) do
    local a, r = ln:match("^METRICS:%s*added=(%d+),%s*removed=(%d+)")
    if a and r then
      added, removed = tonumber(a), tonumber(r)
      metrics_idx = idx
      break
    end
  end

  -- 2. Imprime resumo de alterações no topo da box
  local prefix = " │ "
  if added and removed then
    local summary = string.format("Adicionadas %d linha(s), removida(s) %d linha(s)", added, removed)
=======
function M.render_edit_body(lines, ok, tw)
  local added, removed = nil, nil
  local metrics_idx = nil

  -- 1. Varredura de busca de métricas na string
  for idx, ln in ipairs(lines) do
    local a, r = ln:match("^METRICS:%s*added=(%d+),%s*removed=(%d+)")
    if a and r then
      added, removed = tonumber(a), tonumber(r)
      metrics_idx = idx
      break
    end
  end

  -- 2. Imprime resumo de alterações no topo da box
  local prefix = " │ "
  if added and removed then
    local summary = string.format("Adicionadas %d linha(s), removida(s) %d linha(s)", added, removed)
>>>>>>> REPLACE
```

### Correção 2: Consistência de Sucesso no Replay em `ui/tools_init/executor.lua`
Garantir que os replays de sessões também filtrem o sucesso de ferramentas `Edit` com base na presença de alterações reais, alinhando com o comportamento de execução em tempo real.

**Substituição sugerida em `ui/tools_init/executor.lua`:**
```lua
<<<<<<< SEARCH
function M.tool_replay(cmd, out, ok)
  local tw        = core.tw()
  local name, arg = parser.parse_cmd(cmd)
  if out then
    -- 1. Remove o bloco principal de lembrete do sistema (+ dupla quebra)
    out = out:gsub("\n\n%[SYSTEM: Review your progress.-%]", "")

    -- 2. Remove a linha de autorizacao de seguranca (ANTES do RESOURCE)
    --    Ordem importa: se remover RESOURCE primeiro, o \n antes de
    --    SYSTEM MESSAGE some e o pattern nao casa mais.
    out = out:gsub("\n%[SYSTEM MESSAGE: Security permission for this action was: %S+%]", "")

    -- 3. Remove a linha de metricas de recursos
    out = out:gsub("\n%[RESOURCE METRICS: Execution time: %d+ms%]", "")

    -- 4. Remove os blocos XML de Workspace Attention e TODO Status
    out = out:gsub("\n?<workspace_attention>.-</workspace_attention>", "")
    out = out:gsub("\n?<todo_status>.-</todo_status>", "")
  end
  header.write_header(ok and c.green or c.red, name, arg)
  render_result_body(name, out, ok, tw)
  io.write("\n"); io.flush()
end
=======
function M.tool_replay(cmd, out, ok)
  local tw        = core.tw()
  local name, arg = parser.parse_cmd(cmd)
  if out then
    -- 1. Remove o bloco principal de lembrete do sistema (+ dupla quebra)
    out = out:gsub("\n\n%[SYSTEM: Review your progress.-%]", "")

    -- 2. Remove a linha de autorizacao de seguranca (ANTES do RESOURCE)
    --    Ordem importa: se remover RESOURCE primeiro, o \n antes de
    --    SYSTEM MESSAGE some e o pattern nao casa mais.
    out = out:gsub("\n%[SYSTEM MESSAGE: Security permission for this action was: %S+%]", "")

    -- 3. Remove a linha de metricas de recursos
    out = out:gsub("\n%[RESOURCE METRICS: Execution time: %d+ms%]", "")

    -- 4. Remove os blocos XML de Workspace Attention e TODO Status
    out = out:gsub("\n?<workspace_attention>.-</workspace_attention>", "")
    out = out:gsub("\n?<todo_status>.-</todo_status>", "")
  end

  local actual_ok = ok
  if name == "Edit" then
    actual_ok = parser.is_edit_success(out, ok)
  end

  header.write_header(actual_ok and c.green or c.red, name, arg)
  render_result_body(name, out, actual_ok, tw)
  io.write("\n"); io.flush()
end
>>>>>>> REPLACE
```

---

## 6. Validação do Fix
Após a aplicação destas modificações:
1. Caso um comando `Edit` retorne sem realizar alterações reais (ex: `added=0, removed=0` ou sem métricas), o resumo no topo da box não deve ser exibido (ou, se exibido com `0`, o rodapé e o cabeçalho deverão indicar falha/não aplicação com a cor vermelha e a mensagem `"Substituição falha ❌"`).
2. Durante replays de sessão, qualquer ferramenta `Edit` sem modificações efetivas também será renderizada com cabeçalho vermelho e o rodapé de falha/não aplicada.
