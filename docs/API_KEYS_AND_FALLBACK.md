# Multi-API-key e fallback em camadas

## Modelo de dados e compatibilidade

Cada provedor em `~/.TermAI/agents/main/agent/models.json` aceita `apiKeys`, uma lista ordenada de objetos `{ key, last_ok, last_error_at }`, além de `activeKeyIndex`. O campo legado `apiKey` continua sendo mantido como espelho da chave ativa para compatibilidade com integrações antigas. Na primeira carga, uma configuração que tenha somente `apiKey` é normalizada para uma lista de uma chave e gravada novamente. Chaves vazias e duplicadas são descartadas durante a normalização.

A ordem da lista determina a ordem de rotação. A chave ativa e os timestamps mínimos de sucesso/falha são persistidos; metadados de saúde só são gravados quando o estado muda ou, em estado contínuo, no máximo uma vez por dia por chave, evitando escrita em disco a cada requisição. O arquivo de provedores é salvo por substituição atômica para evitar JSON parcialmente gravado em processos concorrentes. Segredos nunca são impressos, e a interface mostra apenas os últimos quatro caracteres.

## Ordem de recuperação

1. O TermAI usa a chave ativa do provedor do modelo atual.
2. Em falhas retryable, executa as tentativas e os intervalos já configurados em `agents.defaults.request`: `max_retries`, `retry_mode`, `retry_static`, `retry_max`, `timeout`, `idle_timeout` e `wait_timeout`. O caminho síncrono de recuperação usa a mesma política e o mesmo classificador de erros do streaming.
3. Quando a chave esgota as tentativas (ou o classificador determina que a falha não deve ser repetida), o micro fallback avança para a próxima chave do mesmo provedor. O ciclo usa o mesmo `max_retries`; não existe um contador independente de rotação.
4. Somente depois de todas as chaves do provedor atual falharem, o macro fallback percorre `agents.defaults.model.fallbacks` na ordem configurada. Cada item é uma referência `provedor/modelo`, portanto pode apontar para outro provedor.
5. Quando todos os modelos de fallback também falham, a TUI recebe o erro final pelo fluxo já existente. Não há tentativas adicionais fora da lista configurada.

Erros classificados como não retryable continuam respeitando `agent/api/request_stream/error_log.lua`: a chave atual não é repetida, mas o TermAI ainda pode tentar a próxima chave do provedor antes do macro fallback.
Provedores sem chave cadastrada mantêm uma rodada de request sem credencial (`key_rounds` tem piso 1), preservando provedores que não exigem autenticação. Essa compatibilidade é intencional; a rotação entre chaves só ocorre quando há mais de uma chave cadastrada.

## Configuração pela interface

Em `/config` → **Requisições** → **Fallback** (opção 10), tanto na TUI quanto na CLI:

- Gerencie chaves por provedor: adicionar, remover, selecionar a chave ativa e visualizar o estado. A ação legada **Atualizar API Key** substitui somente a chave ativa e preserva as demais.
- Chaves repetidas são recusadas.
- **Testar todas as chaves** executa testes sequenciais no primeiro modelo disponível do provedor, restaura a chave ativa anterior e sugere revisar/remover índices inválidos sem removê-los automaticamente.
- Gerencie a lista ordenada de modelos/provedores de fallback.
- Ative/desative mensagens de transparência da rotação. A opção vem ativada por padrão; o aviso usa o mesmo bloco de status da TUI e é limpo junto com a linha de retry quando a próxima resposta começa.
- O estado de saúde exibe timestamps compactos (`DD/MM/AAAA HH:MM UTC`) em vez do ISO bruto.

A quantidade de tentativas por chave vem exclusivamente de **Max tentativas** na mesma aba Requisições. Os modos e intervalos de espera existentes continuam sendo usados sem criar uma configuração concorrente.

## Segurança e operação

- A interface mascara as chaves e não as inclui em mensagens de rotação.
- Endpoints Google que carregam a chave na query string são redigidos antes de entrar no log de diagnóstico.
- Testes de conexão são sequenciais para evitar rajadas de chamadas ao provedor; mensagens do provedor permanecem disponíveis para diagnóstico, mas são achatadas em uma linha e têm controles ANSI/terminal removidos.
- O fallback síncrono chamado quando o streaming termina sem conteúdo também percorre as chaves e aciona o macro fallback depois de esgotá-las.
- Remover uma chave é uma ação explícita; o teste em lote apenas apresenta sugestões.
