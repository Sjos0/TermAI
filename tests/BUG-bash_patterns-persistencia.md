# Bug: Permissões Exec (bash_patterns) — Não Persistem

**Data:** 2026-07-23
**Status:** HIPÓTESE — Aguardando validação por teste

## Sintomas
1. "Falha no trecho" aparece no dialog de permissão (confuso — não é falha real)
2. Opção 2 ("não perguntar novamente") não persiste entre execuções
3. Safe commands (echo, cat) às vezes pedem permissão desnecessariamente

## Fluxo Investigado
```
engine._pre_tool_use("exec", cmd)
  → perms.get("exec") == "ask"
  → bp.matches(cmd) → rules.matches(cmd)
    → parser.extract_subcommands(cmd)
    → para cada sub: SAFE_COMMANDS? patterns salvos?
  → se não bate: bp.ask_user(cmd, failed_sub)
    → suggest.get_suggested_pattern(failed_sub)
    → ui.ask_user mostra dialog
    → opção 2: rules.add_pattern(pattern) → config_mod.save()
```

## Arquivos Envolvidos
- `agent/hooks/engine.lua` — dispatcher PreToolUse
- `agent/hooks/bash_patterns/rules.lua` — matches() + add_pattern()
- `agent/hooks/bash_patterns/suggest.lua` — gera padrão sugerido
- `agent/hooks/bash_patterns/parser.lua` — extrai subcomandos
- `agent/hooks/bash_patterns/ui.lua` — dialog interativo
- `config/store.lua` — persistência (singleton M._data)

## Hipóteses

### H1: Parser extrai subcomandos que não batem com padrão salvo (90%)
- `suggest` gera `rm *`
- `parser` extrai `rm -f ~/debug_cp.lua` (com redirect cortado)
- `matches_rule("rm -f ~/debug_cp.lua", "rm *")` deveria bater
- Mas pode haver edge cases com heredocs, pipes, etc.

### H2: Config não persiste entre sessões (baixa)
- `config.store` usa singleton `M._data`
- `add_pattern` modifica e salva corretamente
- Padrões aparecem no config.json (confirmado)
- Mas pode haver race condition com restart

### H3: SAFE_COMMANDS não cobre todos os casos (baixa)
- echo, cat, find, grep, lua, lua5.4 estão na lista
- Se dialog aparece para echo, pode ser que `perms.get("exec")` ≠ "ask"

## Solução Proposta (4 mudanças)
1. `ui.lua`: texto "Falha no trecho" → "Subcomando pendente"
2. `suggest.lua`: pattern mais genérico para SAFE_COMMANDS
## Causa Raiz Confirmada (42/42 testes passaram)

**O parser `extract_subcommands` extrai o conteúdo de heredocs como subcomando separado.**

Exemplo:
```
cat << 'EOF' > /tmp/t.txt
conteudo
EOF
```
Parser extrai: `["cat << 'EOF' > /tmp/t.txt", "conteudo"]`

`conteudo` não é `SAFE_COMMAND` nem bate `cat *` → `rules.matches()` retorna `false` → dialog aparece.

**Por que opção 2 não persiste:** o padrão `cat *` é salvo corretamente, mas CADA heredoc tem conteúdo DIFERENTE. Na próxima execução, um novo `conteudo` (ou texto diferente) é extraído e falha o match novamente.

**Patch necessário:** o parser deve tratar heredocs (`<<`) como dados (não como comandos), ou o `matches()` deve ignorar subcomandos que são conteúdo de heredoc.

## Complemento: Caso `sed` (2026-07-23)

O comando `sed -i '117a\-...' file.lua` apareceu no dialog com o texto inteiro.
**Não é bug** — é comportamento correto:
- `sed` não está em `SAFE_COMMANDS` → precisa de permissão
- Parser extrai o `sed` como 1 subcomando (correto, respeita aspas)
- "Falha no trecho" mostra o subcomando inteiro porque o `sed` é longo
- **Diferente do heredoc:** aqui o parser funciona certo, o comando é só complexo

## Comportamento por tipo de comando

| Comando | Funciona? | Por quê |
|---|---|---|
| echo (simples ou &&) | ✅ | SAFE_COMMAND |
| cat arquivo | ✅ | SAFE_COMMAND |
| find, grep, lua, etc. | ✅ | SAFE_COMMAND |
| rm, mv, cp (com padrão) | ✅ | Padrão salvo bate |
| sed, chmod, etc. (sem padrão) | ✅ | Precisa approve (correto) |
| **cat << heredoc** | ❌ | **Parser extrai conteúdo como subcomando** |
| **echo << heredoc** | ❌ | **Mesmo bug — qualquer cmd com heredoc** |
