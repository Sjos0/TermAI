-- tools/subagents/control/parte_2.lua — exporta: enviar, matar_todos.
return function(M, N)
  local registry, scheduler, launcher, owned_by = N.registry, N.scheduler, N.launcher, N.owned_by


  -- Envia mensagem (kind "message") ou redirecionamento ("redirect") a um filho em execução.
  function M.enviar(args, ctx, kind)
    args = type(args) == "table" and args or {}
    local id = tostring(args.runId or "")
    local msg = tostring(args.message or "")
    if msg:match("^%s*$") then return "[FAIL] informe a mensagem (message)." end
    local r = registry.load(id)
    if not r then return "[FAIL] run não encontrado: " .. id end
    if not owned_by(r, ctx) then return "[FAIL] " .. id .. " não é um subagente seu." end
    if scheduler.is_terminal(r) then return "[FAIL] " .. id .. " já terminou (" .. r.status .. "); não recebe mensagens." end
    require("tools.subagents.inbox").post(id, kind, msg)
    if kind == "redirect" then
      return "[REDIRECT] redirecionamento enviado a " .. id .. " (vale a partir do próximo ponto seguro)."
    end
    return "→ mensagem entregue a " .. id .. " no próximo ponto seguro."
  end


  -- Encerra todos os subagentes ativos do dono (kill all). Devolve quantos foram encerrados.
  function M.matar_todos(ctx)
    local n = 0
    for _, r in ipairs(registry.list()) do
      if owned_by(r, ctx) and not scheduler.is_terminal(r) and r.parent_run == nil then
        scheduler.stop_tree(r.runId, "encerrado pelo usuário (kill all)")
        launcher.kill(r.pid, r.runId)
        r.status, r.error, r.finished_at = "killed", "encerrado pelo usuário (kill all)", os.time()
        r.announce_pending = true
        registry.save(r)
        n = n + 1
      end
    end
    return string.format("[OK] %d subagente(s) encerrado(s).", n)
  end
end
