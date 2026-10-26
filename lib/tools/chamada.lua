-- lib/tools/chamada.lua — execução das tools: call, call_structured e format_arg_str (PreToolUse/PostToolUse).
return function(tools, helpers, json, to_disabled_set)
  function tools.call(cmd_string, disabled_tools)
    local t_name, t_arg = cmd_string:match("^([^|]+)|(.*)$")
    if not t_name then return "❌ Erro: Sintaxe inválida." end
    t_name = t_name:match("^%s*(.-)%s*$")
    t_arg  = t_arg and t_arg:match("^%s*(.-)%s*$") or ""
    local dset = to_disabled_set(disabled_tools)
    if dset[t_name] then
      return "❌ Ferramenta '" .. t_name .. "' está desativada para este agente."
    end
    local tool = tools.registry[t_name]
    if not tool then return "❌ Erro: Ferramenta '" .. t_name .. "' não existe." end
    local hooks_engine = require("agent.hooks.engine")
    local allowed, reason = hooks_engine.run("PreToolUse", t_name, t_arg)
    if not allowed then
      return "❌ [PERMISSÃO NEGADA] " .. (reason or "Ferramenta bloqueada.")
    end
    local ok, res = pcall(tool.execute, t_arg)
    if not ok then return "❌ Erro interno: " .. tostring(res) end
    hooks_engine.run("PostToolUse", t_name, t_arg, res)
    return res
  end

  -- Formatação do argumento primário que alimenta PreToolUse/PostToolUse (issue #52).
  -- Dono único: call_structured e o runner (executor) usam esta função; não duplicar.
  function tools.format_arg_str(name, args)
    if type(args) == "table" then
      local primary
      if name == "Grep" then
        primary = string.format('"%s" in %s', args.pattern or "", args.path or ".")
      elseif name == "Read" and args.start_line then
        primary = string.format('%s:%s-%s', args.path or "", args.start_line, args.end_line or args.start_line)
      else
        primary = args.command or args.path  or args.query
               or args.expression or args.name or args.arg
               or args.session_id
      end
      if primary and type(primary) == "string" then
        return primary
      end
      local ok_j, enc = pcall(json.encode, args)
      return ok_j and enc or tostring(args)
    end
    return tostring(args or "")
  end

  function tools.call_structured(name, args, opts)
    opts = opts or {}
    local dset = to_disabled_set(opts.disabled_tools)
    if dset[name] then
      return "❌ Ferramenta '" .. name .. "' está desativada para este agente."
    end
    local tool = tools.registry[name]
    if not tool then return "❌ Ferramenta '" .. name .. "' não existe." end

    if tool.schema and tool.schema.required then
      local a = type(args) == "table" and args or {}
      for _, req in ipairs(tool.schema.required) do
        if not a[req] or a[req] == "" then
          return "❌ Argumento obrigatório ausente: '" .. req
                 .. "' para ferramenta '" .. name .. "'"
        end
      end
    end

    local hooks_engine = require("agent.hooks.engine")
    local arg_str = tools.format_arg_str(name, args)

    if not opts.skip_pretool then
      local allowed, reason = hooks_engine.run("PreToolUse", name, arg_str)
      if not allowed then
        return "❌ [PERMISSÃO NEGADA] " .. (reason or "Ferramenta bloqueada.")
      end
    end

    local ok, res = pcall(tool.execute, args)
    if not ok then return "❌ Erro interno: " .. tostring(res) end
    hooks_engine.run("PostToolUse", name, arg_str, res)
    return res
  end
end
