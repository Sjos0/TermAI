# Fluxo remoto de trabalho (obrigatorio)

Regra do projeto: o trabalho acontece no GitHub (API e CI). O celular so le o resultado.

## Regras

1. **Trabalho remoto primeiro.** A edicao acontece no clone (git); a validacao pesada acontece na CI. O celular so le o resultado.
2. **No celular, nada de suite completa**, nada de greps globais repetidos. So checagem de sintaxe dos arquivos que voce mudou. A suite inteira e da CI.
3. **Commit e push a cada passo pequeno.** Nao espere o fim do trabalho.
4. **Abra a PR como rascunho** ja no primeiro commit funcional. A CI roda em paralelo enquanto voce continua.
5. **Leia a validacao pela API**, nos check runs do ultimo commit. Nao rode a suite no celular.
6. **Se o contexto estiver acabando, commit e push primeiro**, antes de qualquer outra coisa.
7. **Voce NAO mescla.** Entrega a PR PRONTA (sai de rascunho) com CI verde, comenta a evidencia na issue, e PARA. Quem verifica, mescla, fecha a issue e apaga a branch e o **orquestrador**. Mesclar sozinho viola o processo.

   **Nota de rastreabilidade:** o campo `merged_by` da API **nao** identifica quem mesclou, porque todos usam o mesmo token. A evidencia de que o orquestrador verificou fica num **comentario dele na PR ou na issue**, com os numeros da verificacao (PR, CI, medicao, sensibilidade, branch).
8. **Relatorios em palavras, nao em simbolos** (ver #325).

## Fonte de verdade (obrigatorio)

**O corpo da issue e a unica fonte de verdade.**

- Leia o corpo da issue antes de qualquer coisa. Ele manda.
- Comentarios que descrevem um estado ANTERIOR do trabalho (ex.: "Lote 1 aplicado") podem contradizer o corpo. **Nao confie neles.**
- O orquestrador deve marcar esses comentarios como obsoletos ou apaga-los **antes** de disparar um subagente.
- Se o corpo e um comentario divergirem, o corpo vence.

## Comandos prontos (nao escreva um cliente de API do zero)

Copie e adapte. O token ja existe. Nao crie sua propria camada HTTP, nem script de API novo.

```sh
TOKEN=$(grep -oE 'gh[ps]_[A-Za-z0-9_]{20,}' ~/.TermAI/workspace/GITHUB_TOKEN.md | head -1)
API=https://api.github.com/repos/Sjos0/TermAI

# 1. Corpo da issue (fonte de verdade)
curl -s -H "Authorization: Bearer $TOKEN" "$API/issues/N" -o $TMPDIR/i.json
lua5.4 -e 'package.path="/data/data/com.termux/files/home/TermAI/lib/?.lua;"..package.path; print(require("json").decode(io.read("*a")).body)' < $TMPDIR/i.json

# 2. Branch, commit e push
git checkout -b feat/N-slug
git add -A
git -c user.name="Grok (xAI)" -c user.email="grok@xai.invalid" commit -m "tipo(escopo): descricao (#N)"
git push https://x-access-token:$TOKEN@github.com/Sjos0/TermAI.git HEAD:feat/N-slug

# 3. Abrir a PR como rascunho
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" \
  "$API/pulls" -d '{"title":"...","head":"feat/N-slug","base":"main","draft":true,"body":"Closes #N"}'

# 4. Ler a CI (check runs do ultimo commit)
SHA=$(git rev-parse HEAD)
curl -s -H "Authorization: Bearer $TOKEN" "$API/commits/$SHA/check-runs"
```

## Por que

Subagentes anteriores morreram por `timeout` e por `resposta final vazia` depois de rodar a suite completa e greps globais no celular (ARM, lento), consumindo o contexto antes de commitar. Outro gastou o contexto montando um cliente de API do zero e nao entregou nada. O trabalho remoto move esse custo para a CI (Ubuntu, rapida) e mantem o contexto livre para o que importa.
