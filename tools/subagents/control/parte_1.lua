-- tools/subagents/control/parte_1.lua — exporta: MAX_WAIT, tick, sleep, progress, listar, info, esperar, log, matar.
return function(M, N)
  local registry, scheduler, launcher, events, announce, json, card, redact, log, count_tools = N.registry, N.scheduler, N.launcher, N.events, N.announce, N.json, N.card, N.redact, N.log, N.count_tools


  M.MAX_WAIT = 300                                              -- teto de espera de subagents_wait (s)

  M.tick  = function(cfg) return scheduler.tick(cfg) end        -- injetável nos testes

  M.sleep = function(s) os.execute("sleep " .. tostring(s)) end -- injetável nos testes


  -- Progresso de um run em execução: tempo decorrido, tools usadas e o último evento.
  function M.progress(rec)
    local last = events.tail(rec.runId, 1)[1] or ""
    return {
      status = rec.status,
      decorrido_s = rec.started_at and (os.time() - rec.started_at) or 0,
      tools_usadas = count_tools(rec.runId),
      ultimo_evento = last:sub(1, 200),
    }
  end


  function M.listar(args)
    args = type(args) == "table" and args or {}
    local lines = {}
    for _, r in ipairs(registry.list()) do
      if not args.status or args.status == r.status then
        local extra = ""
        if not scheduler.is_terminal(r) then
          local p = M.progress(r)
          extra = string.format(" | %ss | tools=%d", p.decorrido_s, p.tools_usadas)
        end
        lines[#lines + 1] = string.format("%s | %s | %s | agente=%s", r.runId, r.status,
          tostring(r.kind), tostring(r.agentId)) .. extra
      end
    end
    if #lines == 0 then return "Nenhum subagente." end
    return table.concat(lines, "\n")
  end


  -- Cartão de detalhes (formato OpenClaw). formato="json" devolve o registro redigido, para depuração.
  function M.info(args)
    local id = tostring(args.runId or "")
    local r = registry.load(id)
    if not r then return card.unknown(id) end
    if args.formato == "json" then
      local out = {}
      for k, v in pairs(r) do out[k] = type(v) == "string" and redact.clean(v) or v end
      return json.encode(out)
    end
    local extra = { tools = count_tools(r.runId), events_path = registry.dir(r.runId) .. "/events.jsonl" }
    if scheduler.is_terminal(r) then
      extra.result = registry.read_result(r.runId)
    else
      local p = M.progress(r)
      extra.elapsed, extra.last_event = p.decorrido_s, p.ultimo_evento
    end
    return card.build(r, extra)
  end


  -- Espera UM run terminar (até timeoutSeconds, máx. 300) e devolve o resultado.
  -- Marca como entregue: o aviso automático não repete o mesmo resultado depois.
  function M.esperar(args)
    local id = tostring(args.runId or "")
    local r = registry.load(id)
    if not r then return "❌ run não encontrado: " .. id end
    local secs = math.min(tonumber(args.timeoutSeconds) or 60, M.MAX_WAIT)
    local cfg = require("config").load()
    local deadline = os.time() + secs
    while true do
      M.tick(cfg)
      r = registry.load(id)
      if scheduler.is_terminal(r) then
        r.announce_consumed, r.announce_pending = true, false
        r.announced_at = os.time()
        registry.save(r)
        return announce.summary(r)
      end
      if os.time() >= deadline then
        local p = M.progress(r)
        return string.format("⏳ %s ainda rodando após %ds (tools=%d; último evento: %s). Espere de novo ou use subagents_info.",
          id, secs, p.tools_usadas, p.ultimo_evento)
      end
      M.sleep(1)
    end
  end


  function M.log(args)
    local lines = events.tail(args.runId, tonumber(args.lines) or 20)
    if #lines == 0 then return "Sem eventos para " .. tostring(args.runId) end
    return table.concat(lines, "\n")
  end


  function M.matar(args)
    local r = registry.load(args.runId)
    if not r then return "❌ run não encontrado: " .. tostring(args.runId) end
    if scheduler.is_terminal(r) then return "Run já terminado: " .. r.status end
    local children = scheduler.stop_tree(r.runId, "pai morto pelo usuário")
    launcher.kill(r.pid, r.runId)
    r.status, r.error, r.finished_at = "killed", "morto pelo usuário", os.time()
    if children > 0 then r.stopped_children = children end
    r.announce_pending = true
    registry.save(r)
    log.info("run_killed_by_user", { run_id = r.runId })
    return "✓ " .. r.runId .. " encerrado."
  end
end
