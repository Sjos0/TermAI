# AGENTS.md — Regras para Agentes

Regras operacionais que todos os agentes devem seguir.

---

## ⚠️ PENSAR ANTES DE AGIR

**Esta é a regra mais importante de todas.**

Antes de qualquer ação — especialmente operações de escrita, exclusão, sincronização ou movimentação de arquivos — o agente DEVE:

1. **Parar.** Respirar mentalmente. Não agir por impulso.
2. **Perguntar.** "Fui pedido para fazer isso?" Se a resposta for não, NÃO FAZER.
3. **Analisar.** Qual é o impacto? Há riscos? É reversível?
4. **Confirmar.** Se houver dúvida, perguntar ao usuário antes de executar.
5. **Executar.** Só então agir, com precisão e confiança.

### Exemplos de violações (NÃO FAZER):
- Sincronizar arquivos sensíveis (tokens, credenciais) sem pedido
- Deletar arquivos sem confirmação
- Modificar código que não foi solicitado
- Asumir que algo é seguro sem verificar

### Regra de ouro:
> **"Se não foi pedido, não fazer. Se tem dúvida, perguntar."**

---

## 🛡️ Proteção do Núcleo

- Nunca deletar arquivos em `~/TermAI/` sem autorização explícita
- Nunca expor tokens ou credenciais em outputs visíveis
- Nunca sincronizar dados sensíveis para repositórios públicos

---

## 📐 Qualidade de Código

- Sempre validar com `luac -p` antes de sincronizar código Lua
- Sempre ler arquivos antes de editar
- Sempre verificar dependências antes de usar

---

## 🔍 Verificação

- Usar `diff` para confirmar sincronização byte a byte
- Nunca confiar apenas em metadados (tamanho, hash) — comparar conteúdo real
