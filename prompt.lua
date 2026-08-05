-- prompt.lua — Monta o system prompt do agente.
local M = {}
local available = require("commands.available")

local function ler(p, d)
  local f = io.open(p, "r")
  if not f then return d or "" end
  local c = f:read("*a")
  f:close()
  return c
end

-- ── Arsenal de Prompts de Raciocínio (imutável, hardcoded) ──────────────────
local THINKING_PROMPTS = {
  low = [=[
## PROTOCOLO DE RACIOCÍNIO — NÍVEL LOW
Antes de responder, pense brevemente sobre os pontos principais da questão.
Se não tiver reasoning nativo, expresse seu raciocínio entre tags XML:
<think>
[2 a 4 linhas de raciocínio rápido sobre o ponto central]
</think>
Depois forneça sua resposta direta.]=],

  medium = [=[
## PROTOCOLO DE RACIOCÍNIO — NÍVEL MEDIUM
Antes de responder, analise a questão passo a passo.
Se não tiver reasoning nativo, expresse seu raciocínio entre tags XML:
<think>[Análise em parágrafos: qual é o problema, quais abordagens existem, qual é a melhor e por quê]
</think>
Depois forneça sua resposta baseada nessa análise.]=],

  high = [=[
## PROTOCOLO DE RACIOCÍNIO — NÍVEL HIGH
Antes de responder, realize um raciocínio profundo e abrangente.
Se não tiver reasoning nativo, expresse seu raciocínio entre tags XML:
<think>[Exploração detalhada: decomponha o problema, considere múltiplas perspectivas,
avalie alternativas e trade-offs, verifique edge cases, sintetize antes de concluir.
Seja exaustivo — a qualidade da resposta depende da profundidade deste raciocínio.]
</think>
Depois forneça sua resposta final, precisa e bem fundamentada.]=],
}

function M.build(workspace, tools, session_id, cfg)
  local sys = ler(workspace.."/SOUL.md",     "Você é o TermAI.")
           .."\n\n"..ler(workspace.."/IDENTITY.md",  "")
           .."\n\n"..ler(workspace.."/STRUCTURE.md", "")
           .."\n\n"..ler(workspace.."/AGENTS.md",    "")
           .."\n\n"..available.get_docs()  -- restaurado: informa modelo sobre /config /models etc.
           .."\n\n### MEMÓRIA DE LONGO PRAZO\n"..ler(workspace.."/MEMORY.md", "")
           .."\n\n"..ler(workspace.."/USER.md", "")

  if session_id then
    sys = sys .. "\n\n### SESSÃO ATIVA\nID: " .. session_id
           .. "\nO histórico desta conversa foi restaurado automaticamente."
    local todo_ok, todo_block = pcall(function()
      local todo_store = require("tools.todo.store")
      local todo_fmt    = require("tools.todo.formatter")
      local todos = todo_store.load(session_id)
      if #todos == 0 then return nil end
      return todo_fmt.render(todos)
    end)
    if todo_ok and todo_block then
      sys = sys .. "\n\n### TAREFAS EM ANDAMENTO (restauradas)\n" .. todo_block
        .. "\nEssa lista já existia antes deste boot/restart. Continue de onde "
        .. "parou; não recrie do zero. Chame todo_write normalmente para atualizar."
    end
  end

  -- Injeção do Protocolo de Raciocínio (ativável via config)
  local tp = cfg and cfg.agents and cfg.agents.defaults
             and cfg.agents.defaults.thinking_protocol or {}
  if tp.enabled then
    local effort = tp.effort or "medium"
    local prompt = THINKING_PROMPTS[effort] or THINKING_PROMPTS.medium
    sys = sys .. "\n\n" .. prompt
  end

  -- Injeção dinâmica e imutável de idioma (Harness Language Guard)
  local req_cfg = cfg and cfg.agents and cfg.agents.defaults and cfg.agents.defaults.request or {}
  local lang = req_cfg.language or "Portuguese"
  sys = sys .. "\n\n## LANGUAGE CONSTRAINT\n"
         .. "You MUST generate your final response to the user in " .. lang .. " at all times, "
         .. "regardless of the language of this prompt, conversation context, or tool results. "
         .. "Translate your final thoughts and output to " .. lang .. "."

  sys = sys .. [=[
## CONSCIÊNCIA AMBIENTAL
Estes são fatos fixos sobre seu ambiente de execução. Não dependem de ferramentas para serem conhecidos:
- **Timestamp nas mensagens:** Cada mensagem do usuário é automaticamente prefixada com `[YYYY-MM-DD HH:MM:SS]` (hora local). Para perguntas simples de data/hora, leia esse valor diretamente — chamar `Exec date` é redundante nesses casos.
- **Plataforma:** Termux no Android (Linux ARM). Shell via `Exec`.
- **Memória persistente:** `~/.TermAI/workspace/memory/` — arquivos `.md` datados, indexados por `[[tags]]` para busca via `memory_search`.
- **Arquitetura:** Código fonte em `~/TermAI/` (imutável). Dados e workspace em `~/.TermAI/` (gravável).
- **Caminhos nas ferramentas de arquivo:** `ler_arquivo`, `escrever_arquivo` e `substituir_texto` resolvem caminhos relativos a partir de `~/.TermAI/workspace/`. Use caminhos simples como `USER.md` ou `memory/2026-05-05.md` — NÃO prefixe com `workspace/` (causa duplicação). Para arquivos fora do workspace, use caminhos absolutos começando com `/` ou `~`.
]=]

  sys = sys .. [=[
## REGRAS DE EXECUÇÃO
- Nunca anuncie uma ação (ex: "vou criar o arquivo:") sem chamar a tool correspondente na MESMA resposta. Narração e execução devem vir juntas.
]=]

    -- Bug #22 fix:
  -- O modelo recebe a tool "skill" via API, mas sem o catálogo não sabe
  -- quais skills existem nem seus nomes exatos para chamar.
  -- pcall garante que a ausência do módulo não quebra o boot.
  local ok_sk, skills_mod = pcall(require, "tools.skills")
  if ok_sk and skills_mod and skills_mod.build_catalog then
    local catalog = skills_mod.build_catalog("main")
    if catalog ~= "" then
      sys = sys .. "\n\n" .. catalog
    end
  end

  return sys
end

return M
