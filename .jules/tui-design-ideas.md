# 🎨 TermAI Mobile TUI: Proposta de Melhorias de Design & UX
*Criado pela persona Palette — Foco em Micro-UX, Acessibilidade e Delight no Termux Móvel*

Este documento apresenta uma análise detalhada da interface interativa (TUI) do TermAI no ambiente móvel Termux, identificando pontos de fricção específicos de usabilidade em smartphones e propondo soluções práticas e perfeitamente implementáveis.

---

## 1. Redução Inteligente da Área de Diffs de Código (`Edit` Tool)

### 🔍 O que mudar
No renderizador especializado de diffs em `ui/tools_init/edit_renderer.lua`, substituir a exibição literal e estendida de todas as linhas de alteração por um **Modo de Diff Compacto com Colapso de Contexto**.
- Ocular linhas de contexto idênticas distantes da alteração.
- Exibir apenas as $N$ linhas imediatamente anteriores e posteriores à linha alterada.
- Utilizar uma linha divisória sutil contendo o marcador numérico das linhas ocultas (ex: `... (15 linhas ocultas) ...` em tom cinza claro `c.dim`).

### 🎯 Por que importa
Em telas de smartphones orientadas em modo retrato, a largura útil geralmente varia entre 70 e 80 colunas e o espaço vertical é extremamente limitado pelo teclado virtual ativo. Atualmente, se o modelo faz pequenas alterações em arquivos médios (ex: 50 a 100 linhas), a ferramenta de edição renderiza longos trechos intactos. Isso gera:
1. Rolagem excessiva.
2. Quebra indesejada de linhas horizontais (`wrap_para`), fragmentando a legibilidade do código.
3. Desorientação do usuário sobre o que realmente mudou.

### 📈 Impacto Estimado
**Altíssimo (9/10).** Economiza até 70% da rolagem vertical durante a edição de arquivos, permitindo que o usuário visualize o início, o diff exato e o fim da execução da ferramenta em um único quadro de tela móvel sem precisar rolar.

---

## 2. Diálogo de Permissões Interativo com Entrada de Caractere Único (`Single-Key` / `Hotkeys`)

### 🔍 O que mudar
No diálogo interativo de permissões de execução em `tools/exec/permissions_ui.lua`:
- Alterar o loop de leitura de teclado para aceitar um caractere único e instantâneo (`raw mode`), em vez de exigir que o usuário digite o número e pressione obrigatoriamente a tecla `Enter`.
- Mapear atalhos simples e intuitivos:
  - Tecla `y` ou `Space` (Espaço): Aprovar uma vez (o mais comum).
  - Tecla `a`: Permitir sempre para o padrão.
  - Tecla `n` ou `BackSpace`: Negar.
  - Tecla `b`: Bloquear permanentemente.
  - Tecla `Esc` ou `c`: Cancelar.
- Destacar visualmente esses atalhos na interface com cores suaves (ex: sublinhado ou parênteses em destaque: `(Y) Sim / (N) Não`).

### 🎯 Por que importa
Digitar no teclado virtual do Android (como Gboard, SwiftKey ou Termux Extra Keys) possui alta fricção. O usuário precisa:
1. Toque para abrir o teclado.
2. Toque para digitar um número (`1`, `2`, `3`, `4` ou `c`).
3. Toque para pressionar a tecla de confirmação `Enter`.
Eliminar a necessidade de pressionar `Enter` e focar em teclas fáceis de tocar na barra auxiliar de atalhos do Termux reduz drasticamente o esforço físico repetitivo.

### 📈 Impacto Estimado
**Crítico (10/10).** Transforma o momento de maior interrupção do fluxo de trabalho do agente (esperar autorização de comandos como `git`, `npm` ou `grep`) em uma experiência fluida e instantânea com apenas um toque na tela.

---

## 3. Indicador de Pensamento Suave e Estabilização de Flicker (Reasoning Box)

### 🔍 O que mudar
Nas rotinas de animação em `ui/stream/ansi_helpers.lua` e `ui/stream/reasoning_box.lua`:
- Substituir a animação clássica de três pontos alternantes (`Pensando.`, `Pensando..`, `Pensando...`) que faz a linha oscilar por um **Spinner Unicode Estático e Rotativo** de largura física fixa (ex: caracteres braille como `⠋`, `⠙`, `⠹`, `⠸`, `⠼`, `⠴`, `⠦`, `⠧`, `⠇`, `⠏` ou um indicador de carregamento discreto).
- Garantir que a área reservada no cabeçalho do box de pensamento (`header_label`) tenha tamanho exato para evitar qualquer oscilação ou tremor vertical e horizontal na tela.

### 🎯 Por que importa
Muitos emuladores de terminal de smartphone não atualizam frames ANSI com a mesma eficiência de uma GPU desktop. A alteração de largura de strings em tempo real (provocada pela variação do número de pontos `.` e espaços) força o terminal a recalcular a largura de linha, causando um efeito de "flicker" (tremor) altamente desconfortável aos olhos, especialmente sob conexões de internet móvel instáveis onde o modelo demora para gerar a resposta.

### 📈 Impacto Estimado
**Médio-Alto (7/10).** Fornece uma sensação de estabilidade, polimento e "delight" estético, eliminando ruído visual na tela do smartphone.

---

## 4. Padding Adaptável e Layout Flexível para Telas Estreitas

### 🔍 O que mudar
No arquivo `ui/messages.lua` e no renderizador de parágrafos de `ui/core.lua`:
- Introduzir uma detecção inteligente de largura. Se `core.tw()` for inferior a 80 colunas (indicativo claro de smartphone em modo retrato):
  - Reduzir o padding horizontal de mensagens de 4 caracteres para **2 caracteres**.
  - Em vez do ponto circular grande `⬤` que ocupa muito espaço horizontal de forma destacada, utilizar uma linha de margem vertical de cor cinza suave (`│`) na lateral esquerda para separar as respostas da IA das do usuário.
- Ajustar os limites máximos de caracteres das visualizações embutidas.

### 🎯 Por que importa
No smartphone, a densidade de informação é rei. Perder 8 caracteres de largura apenas com margens de parágrafo (4 à esquerda + 4 à direita) em uma tela de 72 colunas significa sacrificar **mais de 11% de toda a área útil de leitura**. Isso espreme as palavras, gera hifenizações artificiais horríveis e dobra o número de linhas necessárias para exibir a mesma resposta.

### 📈 Impacto Estimado
**Alto (8/10).** Melhora substancialmente o fluxo de leitura das respostas complexas da IA no celular, permitindo que explicações técnicas e trechos de código de ferramentas caibam de forma muito mais íntegra horizontalmente.

---

## 5. Feedback Visual Auto-Dismissível em Menus e Diálogos TUI

### 🔍 O que mudar
Nos menus de configuração de modelos e provedores (em `commands/models/menu.lua` e submenus sob `commands/config/menus/`):
- Substituir a chamada obrigatória do método bloqueante de pausa `ui.pause()` por um **Temporizador de Confirmação Auto-Dismissível** para ações de sucesso não-críticas (como salvar chave de API, ativar modelo ou limpar fila).
- Ao realizar uma alteração bem-sucedida, exibir uma notificação visual elegante por 1.2 segundos (ex: `✅ Sucesso! Retornando...`) e retornar automaticamente para o menu pai, eliminando a tela preta com o texto estático "Pressione Enter para continuar...".

### 🎯 Por que importa
A pausa clássica "Pressione Enter" é uma herança de terminais desktop antigos. Em um celular, ela quebra completamente o fluxo de interação, obrigando o usuário a esticar o dedo para tocar no botão "Enter" virtual do teclado para confirmar uma ação que o sistema já informou ter sido concluída com sucesso.

### 📈 Impacto Estimado
**Médio (6/10).** Torna a experiência de configurar e alternar modelos ou provedores no TermAI extremamente rápida, assemelhando-se à fluidez de um aplicativo móvel nativo.

---

*Palette 🎨 — "Cada caractere importa, cada pixel no mobile conta!"*
