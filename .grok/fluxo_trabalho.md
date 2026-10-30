# Fluxo de trabalho TermAI (implementador)

## Regras
1. Nunca trabalhar em `~/TermAI` do usuário; clone em `~/work_termai`.
2. Uma branch e uma PR por issue; nunca push direto na main.
3. Nunca mesclar com CI vermelho.
4. Nenhum teste pode copiar lógica de produção — executar o código real (ou subprocesso).
5. Ao concluir: PR mesclada, issue fechada com evidência, branch apagada.
6. Sem tokens/credenciais em arquivo, commit, log ou memória.
7. Registro em `.grok/grok.md` e `.claude/claude.md` no mesmo patch.
8. Termux e Ubuntu.
9. ≤150 linhas fora de `lib/` e `tests/`.
10. Commits: `Grok (xAI)` / `grok@xai.invalid`; mensagem `tipo(escopo): descrição`.
11. Pontos de injeção de teste inertes por padrão.

## Análise de validade (antes de implementar)
1. Ler a issue inteira.
2. Confirmar o problema no código (arquivo + linha).
3. Comentar veredito: CONFIRMADA | PARCIAL | NÃO CONFIRMADA.
4. Só implementar se CONFIRMADA/PARCIAL.

## Fluxo por issue
3.1 Clone fresco + pull main  
3.2 Validade + comentário na issue  
3.3 Branch `fix/<n>-<slug>`  
3.4 Specs de aceite primeiro (falham antes quando cabível)  
3.5 Implementação mínima  
3.6 **Prova de sensibilidade (local, sem commit):** reintroduzir defeito → spec falha → `git checkout --` restaurar  
3.7 Validação local (sintaxe, suíte, PTY, wc -l)  
3.8 Registro nos dois `.md`  
3.9 Commit + push  
3.10 PR com tabela critério→evidência + saída de sensibilidade  
3.11 CI verde  
3.12 Merge  
3.13 Fechar issue  
3.14 Apagar branch  

## Release
PATCH se só correção/prova; confirmar VERSION; tag `vX.Y.Z`; notes em português.

## Lições
- PASS sem prova de falha no defeito reintroduzido não vale.
- grep sozinho não prova comportamento.
- "Resolvido" só com evidência anexada.
