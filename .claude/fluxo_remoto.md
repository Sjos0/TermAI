# Fluxo remoto de trabalho (obrigatorio)

Regra do projeto: o trabalho acontece no GitHub (API e CI). O celular so le o resultado.

1. **Trabalho remoto primeiro.** Edicao e validacao acontecem no GitHub (API e CI). O celular so le o resultado.
2. **No celular, nada de suite completa**, nada de greps globais repetidos. So checagem de sintaxe dos arquivos que voce mudou.
3. **Commit e push a cada passo pequeno.** Nao espere o fim do trabalho.
4. **Abra a PR como rascunho** ja no primeiro commit funcional. A CI roda em paralelo enquanto voce continua.
5. **Leia a validacao pela API**, nos check runs do ultimo commit.
6. **Se o contexto estiver acabando, commit e push primeiro**, antes de qualquer outra coisa.
7. **So marque concluido com:** CI verde no ultimo commit, `Closes #<n>` no corpo, issue fechada com comentario de evidencia, e branch apagada.
8. **Relatorios em palavras, nao em simbolos** (ver #325).

## Por que

Subagentes anteriores morreram por `timeout` e por `resposta final vazia` depois de rodar a suite completa e greps globais repetidos no celular (ARM, lento), consumindo o contexto antes de commitar. O trabalho remoto move esse custo para a CI (Ubuntu, rapida) e mantem o contexto livre para o que importa.
