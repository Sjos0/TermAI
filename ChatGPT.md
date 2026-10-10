# TermAI — memória operacional do projeto

Este documento registra decisões operacionais duráveis, referências técnicas e evidências de manutenção. Mudanças devem ser pequenas, verificadas, documentadas e publicadas com commits convencionais. Em uma emergência, uma correção pode entrar diretamente em main, mas deve vir acompanhada de evidência e registro.

## Arquitetura atual na VPS

- Repositório: /home/ubuntu/projects/TermAI, remoto Sjos0/TermAI.
- Implementação principal: Lua 5.4.
- Executável: /home/ubuntu/.local/bin/TermAI, apontando para o checkout do repositório.
- Execução sob demanda: TermAI run --prompt-file arquivo.md --model provider/model --max-iter N. Cada execução cria uma sessão isolada e termina quando o turno acaba.
- O Kilo CLI e seu daemon foram removidos. O TermAI chama diretamente o endpoint OpenAI-compatible https://api.kilo.ai/api/gateway/chat/completions.
- Modelos: primário kilo/kilo-auto/free; fallback kilo/openrouter/free; três tentativas por modelo, conforme request.max_retries=3. Rotas gratuitas podem sofrer rate limits e têm políticas próprias de logging; nunca colocar segredos nos prompts.
- Permissões de ferramenta estão em modo bypass na configuração local da VPS, conforme autorização do operador. Tratar prompts de jobs como código confiável, porque ferramentas podem executar comandos e alterar o GitHub sem confirmação.

## Jobs e evidências

Os runners e prompts operacionais são versionados em scripts/automation/ e usados pelos caminhos compatíveis com o cron em /home/ubuntu/.local/bin/.

- Bugs Hunter: todos os dias às 00:00, timezone America/Sao_Paulo.
- Code Review: todos os dias às 00:30, timezone America/Sao_Paulo.
- Lock compartilhado: /home/ubuntu/.local/state/termai-nightly.lock.
- Logs, snapshots do repositório, PRs e Issues, resumo e veredito: /home/ubuntu/.local/state/termai/jobs/<job>/<timestamp>/.
- O runner aborta em checkout sujo, falta de autenticação GitHub ou indisponibilidade do modelo, registrando o motivo. A execução não deve alterar código de PRs como efeito colateral de uma revisão.

### Comandos de automação

- TermAI cron list: lista os jobs TermAI existentes no crontab.
- TermAI cron run bugs-hunter: executa o runner oficial do Bugs Hunter agora.
- TermAI cron run code-review: executa o runner oficial de Code Review agora.
- TermAI cron runs code-review 10: consulta os resumos das últimas dez execuções.

Nesta primeira versão, TermAI cron usa o cron do sistema como backend e não mantém um daemon residente. O CLI apenas lista, dispara manualmente e consulta o histórico; a instalação e edição dos horários ainda são feitas no crontab.

### Contrato de labels do GitHub

- Bugs Hunter só trabalha em Issues que tenham agent:needs-bugs-hunter ou agent:needs-investigation; se não houver trabalho pendente, deve encerrar sem alterações.
- Code Review só revisa PRs com agent:needs-code-review e ainda não revisadas para o SHA atual.
- O comentário automatizado é vinculado ao HEAD exato. A publicação atualiza o comentário anterior em vez de criar duplicatas.
- Só depois de publicar e verificar o comentário para o SHA atual é permitido remover agent:needs-code-review e adicionar agent:code-review-reviewed.
- Os helpers versionados termai-gh-review-publish.py e termai-gh-review-finish.py evitam expansão acidental de crases/aspas pelo shell e impedem que uma PR com HEAD alterado seja marcada como revisada.

### Teste manual realizado em 2026-10-10

- Bugs Hunter: exit code 0; concluiu que não havia Issues elegíveis e que as PRs já tinham marcador de triagem correspondente ao HEAD. Nenhuma alteração foi necessária.
- Code Review: exit code 0 na execução de 16:29–16:32; o modelo primário retornou HTTP 429 após três tentativas e o fallback respondeu. Comentários vinculados aos SHAs atuais foram verificados nas PRs #75 e #80.
- PR #75: 47c2dcfca21555c7821d896ce8c8b2710c7bd2fc, labels finais incluem agent:code-review-reviewed e agent:bugs-hunter-reviewed.
- PR #80: c8872425aaa36d9d957984a8bd5f5a8b4403311e, labels finais incluem agent:code-review-reviewed e agent:bugs-hunter-reviewed.
- O primeiro teste de Code Review falhou por limite de iterações; o segundo foi interrompido para corrigir a publicação segura; a terceira execução concluiu. Esses resultados permanecem no histórico local para auditoria.
- O comando TermAI cron run bugs-hunter foi testado após o commit 77ced76: o runner executou o fluxo completo e terminou com exit code 0. A triagem vazia demorou cerca de 2 min 35 s; por isso, o prompt do Bugs Hunter agora exige saída imediata quando não há Issues elegíveis e todas as PRs já estão marcadas para o HEAD atual.
- RAM disponível na verificação final: aproximadamente 210 MiB de 954 MiB; o Kilo daemon não estava instalado/ativo.

## Referência OpenClaw instalada na VPS

OpenClaw permanece instalado e não foi alterado. Inspecionei a documentação local instalada em /usr/lib/node_modules/openclaw/docs/cli/.

Padrões relevantes para trazer gradualmente ao TermAI:

1. openclaw agent executa um turno não interativo e oferece seleção explícita de agente/sessão, timeout e saída JSON.
2. openclaw cron administra jobs no scheduler do Gateway, permite execução manual e consulta do histórico por job.
3. O cron do OpenClaw mantém histórico de execuções e backoff exponencial depois de falhas recorrentes; execução manual é enfileirada e pode ser acompanhada por run ID.
4. O OpenClaw usa contexto isolado por execução, opção de contexto leve e separa execução do agente da entrega do resultado.

Estado local observado: nove jobs configurados, oito desabilitados e um habilitado (Memory Dreaming Promotion, às 03:00). Não alterei esses jobs nem o Gateway.

O TermAI já adotou a primeira fatia desses padrões: execução headless e isolada, cron sem daemon residente, execução manual do mesmo runner, histórico persistente, fallback, snapshots e publicação de revisão idempotente vinculada ao SHA. Próximas melhorias possíveis: gerenciamento de schedules pelo próprio CLI, timeout nativo e saída JSON estruturada, mantendo o consumo de RAM baixo.

## Processo de contribuição

- Usar os agentes versionados para triagem e revisão quando houver trabalho elegível.
- Não confiar apenas no exit code do agente: verificar comentários, marcador de HEAD, labels, snapshots e resumo.
- Executar verificações de sintaxe e testes relevantes antes de commit.
- Commits convencionais, focados e com documentação correspondente.
- Manter mudanças operacionais em scripts/automation/, não em arquivos soltos fora do repositório.
