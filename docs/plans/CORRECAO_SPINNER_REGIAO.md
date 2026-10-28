# Correção do spinner e da região de rolagem

## Sintomas no Moto G8 Play (v1.32)
- Cursor (bloco branco) parado perto do colchete do spinner.
- Ao fechar o teclado, "Trabalhando" subia e sobrescrevia o conteúdo.
- Ao fim da resposta, "Requisitando" continuava em loop.
- Linhas "[=== ] Trabalhando" soltas no conteúdo.

## Causas raiz
1. Posição absoluta (`ESC[rows;1H`) com altura lida uma vez e gravada em arquivo. Teclado e rotação mudam a altura; o arquivo fica velho.
2. Spinner em processo `sh` separado escrevendo no terminal ao mesmo tempo que o processo Lua. Duas fontes escrevendo no mesmo terminal sem coordenação.
3. Região de rolagem (DECSTBM) não é reajustada quando o terminal muda de tamanho.
4. O spinner não para junto com o turno no modo sem região (corrigido no hotfix pelo caminho antigo de `stop_thinking`).

## Hotfix desta versão
- Modo região desligado (`REGIAO_ATIVA = false`).
- Spinner escreve só na linha atual (`\r` + `ESC[K`), sem posição absoluta e sem `ESC 7/8`.
- Brilho nos rótulos e máquina Injetando → Requisitando → Trabalhando mantidas.
- Testes: nenhuma sequência de posição absoluta é emitida, mesmo com arquivo de altura antigo presente; ticks de animação com `\r`.

## Referência (Codex, pesquisa parcial)
- O Codex usa TUI de tela cheia (ratatui): ele desenha o quadro inteiro a cada frame, com tamanho do terminal consultado na hora, sem região de rolagem e sem processo externo.
- A animação do rótulo é um brilho por caractere calculado por tempo, dentro do próprio processo.
- Não li o código-fonte do `shimmer.rs` por completo; o plano abaixo depende dessa leitura.

## Plano da versão definitiva (região v2)
1. Ler a altura a cada quadro, nunca gravar em arquivo.
2. Um único escritor no terminal: o processo Lua. O spinner vira estado + quadro, desenhado pelo Lua.
3. Animação: tick de tempo dentro do Lua, sem processo externo (exige loop que não bloqueia; estudar `io.popen` não bloqueante ou thread via `coroutine` com leitura por linha).
4. Região só com teste em pseudo-terminal (script/expect) e no Moto, antes de ligar `REGIAO_ATIVA`.
5. Ctrl+C e saída: wrapper com `trap` (já existe no `install.sh`).
